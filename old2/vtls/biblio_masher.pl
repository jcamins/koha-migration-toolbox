#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# This script is intended to ingest a MARC-formatted bib/item file from 
# VTLS Virtua, and write an output file in a form that can be 
# fed to ByWater's General Purpose Database Table Loader script, for items,
# and a MARC file for bulkmarcimport, cleaned up, for the MARCs.
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
my $marcfile_name = "";

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
my $ebrary_skip=0;
my $westbook=0;
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
   if ($record->subfield("710","a")){
   if ($record->subfield("710","a") =~ /ebrary/){
      $ebrary_skip++;
      next;
   }}

   my $price = 0;

   if ($record->subfield("350","a")){
      $price = $record->subfield("350","a");
      #$price =~ s/\D\.]//;
      $price =~ s/(\d+(\.[0-9]{2}))/$1/;
      $price =~ s/\$//g;

   }
   my $repl_price = ($price < 60.00 ? 60 : $price);

   my $bibcall = $record->subfield("090","a")." ".$record->subfield("090","b");

   my %homebranch;
   my %itype;
   my %itemcall;
   my %itemnote;
   my $deftype="";

   foreach my $field ($record->field("949")){
      
      # BARCODE
     
      my $barcode=$field->subfield("6");

      # HOMEBRANCH/HOLDINGBRANCH

      if ($field->subfield("D") eq "10009"){
          $homebranch{$barcode} = "WEST"; 
          $westbook++;
      }
      else {
          $homebranch{$barcode} = "MAIN"; 
      }

      # ITEM CALL

      if ($field->subfield("a")){
          $itemcall{$barcode} = $field->subfield("a");
      }
      else {
          $itemcall{$barcode} = $bibcall;
      }
 
      # ITYPE
  
      $itype{$barcode} = "BOOK";

      my $locn = $field->subfield("D");
      $itype{$barcode} = "SPCOLL" if ($locn eq "10004"); 
      $itype{$barcode} = "ILL" if ($locn eq "10010"); 
      $itype{$barcode} = "ARCHIVE" if ($locn eq "10003"); 
      $itype{$barcode} = "REF" if ($locn eq "10002"); 
      
      $itype{$barcode} = "CDROM" if ($itemcall{$barcode} =~ "^CD-ROM");      
      $itype{$barcode} = "KIT" if ($itemcall{$barcode} =~ "^KIT");      
      $itype{$barcode} = "PASS" if ($itemcall{$barcode} =~ "^PASS");      
      $itype{$barcode} = "VHS" if ($itemcall{$barcode} =~ "^VHS");      
      $itype{$barcode} = "DVD" if ($itemcall{$barcode} =~ "^DVD");      
      $itype{$barcode} = "MUSIC" if ($itemcall{$barcode} =~ "^CD");      
      $itype{$barcode} = "CASSBOOK" if ($itemcall{$barcode} =~ "^CASS");      
      $itype{$barcode} = "CDBOOK" if (substr($record->leader(),6,1) eq "i");      
      $types{$itype{$barcode}}++;
      $deftype = $itype{$barcode};

      #NOTE

      $itemnote{$barcode} = $field->subfield("9");

   }
   foreach my $dumpfield($record->field('9..')){
      $record->delete_field($dumpfield);
   }
   if ($deftype eq ""){
     $deftype = $bibcall =~ "^Per" ? "PERIOD" : "BOOK";
     if ($record->subfield("710","a") =~ /NetLibrary/){
        $deftype = "EBOOK";
     }
     $types_noitem{$deftype}++;
   }
   my $deffield=MARC::Field->new("942"," "," ","c" => $deftype);
   $record->insert_grouped_field($deffield);

   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $homebranch{$key},
        "o" => $itemcall{$key},
        "y" => $itype{$key},
        "g" => $price,
        "z" => $itemnote{$key},
        "2" => "lcc",
        "v" => $repl_price);
      $record->insert_grouped_field($itmtag);
   }

   print MARCFL $record->as_usmarc();
}
close MARCFL;

print "\n\nRESULTS BY CATEGORYCODE\n";
foreach my $kee (sort keys %types){
   print $kee.":   ".$types{$kee}."\n";
}


print "COUNTS OF NO-ITEMS TYPES:\n";
foreach my $kee (sort keys %types_noitem){
   print $kee.":   ".$types_noitem{$kee}."\n";
}

print "\nWEST BOOKS: $westbook\n\n";
print "Ebrary skipped: $ebrary_skip\n";
