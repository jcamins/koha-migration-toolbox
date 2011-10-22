#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# This script is intended to ingest a MARC-formatted bib/item file from 
# TLC, and write a MARC file for bulkmarcimport, cleaned up, for the MARCs.
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use Getopt::Long;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;


my $infile_name = "";
my $outfile_name = "";
my $debug = 0;

GetOptions(
    'in=s'     => \$infile_name,
    'out=s'    => \$outfile_name,
);

if (($infile_name eq '') || ($outfile_name eq '')){
    print << 'ENDUSAGE';

Usage:  biblio_masher --in=<infile> --out=<outfile> 

<infile>     A MARC-formatted data file, from which you wish to extract data.

<outfile>   A MARC-formatted output file, for cleaned MARC records.

ENDUSAGE
exit;
}

open MARCFL,">:utf8", $outfile_name;

my $fh = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$fh);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
my $i=0;
my %types;
my %types_noitem;
while () {
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);
   last if ($debug && $i>100);

   my $price = 0;

   if ($record->subfield("350","a")){
      $price = $record->subfield("350","a");
      #$price =~ s/\D\.]//;
      $price =~ s/(\d+(\.[0-9]{2}))/$1/;
      $price =~ s/\$//g;

   }
   
   my $bibcall;
 
   if ($record->field("092")){
      $bibcall = $record->subfield("092","a")." ".$record->subfield("092","b");
   }

   my %homebranch;
   my %itype;
   my %itemcall;
   my %itemnote;
   my %acqsource;
   my %acqdate;
   my %itmprice;
   my %replprice;
   my %enumchron;
   my %copynum;

   foreach my $field ($record->field("949")){

      my $holdcode=$field->subfield("a");
      if (($holdcode eq "") ||
          ($holdcode eq "JQNEV") ||
          ($holdcode eq "JQNFK") ||
          ($holdcode eq "JQNFV") ||
          ($holdcode eq "JQNKV") ||
          ($holdcode eq "JQNNV") ||
          ($holdcode eq "JQNQV") ||
          ($holdcode eq "DCR") ||
          ($holdcode eq "DNR") ||
          ($holdcode eq "DOC") ||
          ($holdcode eq "ERR") ||
          ($holdcode eq "INT") ||
          ($holdcode eq "MAG") ||
          ($holdcode eq "MAGS") ||
          ($holdcode eq "fgbj")){
         next;
      }
      $holdcode = uc $holdcode;

      # BARCODE
     
      my $barcode=$field->subfield("l");

      # DATE ACQUIRED 
     
      if ($field->subfield("d")){
         $field->subfield("d") =~ /(\d*)\/(\d{2})/;
         my $month = ($1);
         my $year = ($2);
      
         if ($year < 11){
           $acqdate{$barcode} = sprintf "%04d-%02d-01",$year+2000,$month;
         }
         else {
           $acqdate{$barcode} = sprintf "%04d-%02d-01",$year+1900,$month;
         }
      }
 
      # ACQ SOURCE 

      if ($field->subfield("e")){
         $acqsource{$barcode} = $field->subfield("e");
      }

      # ITYPE

      if ($holdcode =~ /FOL/ || length($holdcode) == 4){
          $itype{$barcode} = $holdcode;
      }
      else {
          $itype{$barcode} = substr($holdcode,0,4);
      } 

      $types{$itype{$barcode}}++;

      # PRICE / REPL PRICE 
      
      my $tmpprice = 0;
      if ($field->subfield("p")){
         $tmpprice = $field->subfield("p");
         $tmpprice =~ s/(\d+(\.[0-9]{2}))/$1/;
         $tmpprice =~ s/\$//g;
      }
      $itmprice{$barcode} = $tmpprice || $price;

      $replprice{$barcode} = $itmprice{$barcode} + 10;

      if (($itype{$barcode} eq "JQN5") || ($itype{$barcode} eq "JQN7")){
          $replprice{$barcode} += 8;
      }

      # SERIAL ENUM/CHRON

      if ($field->subfield("v")){
          $enumchron{$barcode} = $field->subfield("v");
      }

      # COPY NUMBER
    
      if ($field->subfield("c")){
          $copynum{$barcode} = $field->subfield("c");
          $copynum{$barcode} =~ s/\D//;
          $copynum{$barcode} =~ s/\.//;
          $copynum{$barcode} =~ s/ //;
      }

      # HOMEBRANCH/HOLDINGBRANCH

      if (length($holdcode) == 5 && $holdcode =~ /S$/){
          $homebranch{$barcode} = "SMITH";
      }
      else {
          $homebranch{$barcode} = "DE";
      }

      # ITEM CALL

      if ($field->subfield("g")){
          $itemcall{$barcode} = $field->subfield("g");
      }
      else {
          $itemcall{$barcode} = $bibcall;
      }
 
      #NOTE

      if ($field->subfield("n")){
          $itemnote{$barcode} = $field->subfield("n");
      }

   }
   foreach my $dumpfield($record->field('9..')){
      $record->delete_field($dumpfield);
   }

   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $homebranch{$key},
        "o" => $itemcall{$key},
        "y" => $itype{$key},
        "g" => $itmprice{$key},
        "v" => $replprice{$key},
        "2" => "lcc",
      );
      $itmtag->update( "h" => $enumchron{$key}) if ($enumchron{$key});
      $itmtag->update( "t" => $copynum{$key} ) if ($copynum{$key});
      $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
      $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
      $itmtag->update( "e" => $acqsource{$key} ) if ($acqsource{$key});
      $record->insert_grouped_field($itmtag);
   }

   print MARCFL $record->as_usmarc();
}
close MARCFL;

print "\n\nRESULTS BY CATEGORYCODE\n";
foreach my $kee (sort keys %types){
   print $kee.":   ".$types{$kee}."\n";
}



