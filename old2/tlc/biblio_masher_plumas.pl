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
my $k=0;
my %types;
my %types_noitem;
my %itype_map = (
"SCL","AUD",
"AB","ANF",
"AC","AC",
"AF","AF",
"ANF","ANF",
"AX","XMS",
"BB","BB",
"CC","CC",
"CD","MD",
"CRF","CRF",
"E","E",
"ILR","ILL",
"JB","JNF",
"JC","JC",
"JF","J",
"JFT","JFT",
"JNF","JNF",
"JX","XMS",
"LA","AC",
"LD","MD",
"LS","LS",
"LT","LT",
"M","M",
"PS","PS",
"R","R",
"REF","REF",
"SC","REF",
"SF","SF",
"SP","SP",
"SS","SS",
"VC","VC",
"VD","VD",
"W","W",
"YA","YA",
"YP","YA");
while () {
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   next if ($i <= 60892);
   
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
   
   my $bibcall="";
 
   if ($record->field("082")){
      $bibcall = $record->subfield("082","a")." ".$record->subfield("082","b");
   }
   if ($record->field("092")){
      $bibcall = $record->subfield("092","a")." ".$record->subfield("092","b");
   }
  

   my %homebranch;
   my %itype;
   my %itemcall;
   my %itemnote;
   my %pubnote;
   my %acqsource;
   my %acqdate;
   my %itmprice;
   my %replprice;
   my %enumchron;
   my %copynum;

   foreach my $field ($record->field("949")){

      my $holdcode=uc substr($field->subfield("a"),1,999);
      if (($holdcode eq "") ||
          ($holdcode eq "AM") ||
          ($holdcode eq "JM") ||
          ($holdcode eq "ORD")){
         next;
      }

      # BARCODE
     
      my $barcode=$field->subfield("b");

      # DATE ACQUIRED 
     
      if ($field->subfield("x")){
         my ($year,$month,$day);
         if (length($field->subfield("x")) == 6){
           $year = substr($field->subfield("x"),0,2);
           $month = substr($field->subfield("x"),2,2);
           $day = substr($field->subfield("x"),4,2);
         } 
         else {
           $year = substr($field->subfield("x"),0,4);
           $month = substr($field->subfield("x"),4,2);
           $day = substr($field->subfield("x"),6,2);
         }
         if ($year <11 && ($record->publication_date()>1930 || $field->subfield("h")>1930)){
           $year += 2000;
         }
         elsif ($year <100){
           $year += 1900;
         }
         $acqdate{$barcode} = sprintf "%04d-%02d-%02d",$year,$month,$day;
      }
 
      # ACQ SOURCE 

      if ($field->subfield("s")){
         $acqsource{$barcode} = $field->subfield("s");
      }

      # ITYPE
   
      $itype{$barcode} = $itype_map{$holdcode};

      $types{$itype{$barcode}}++;

      # PRICE / REPL PRICE 
      
      my $tmpprice = 0;
      if ($field->subfield("e")){
         $tmpprice = $field->subfield("e");
         $tmpprice =~ s/(\d+(\.[0-9]{2}))/$1/;
         $tmpprice =~ s/\$//g;
      }
      $itmprice{$barcode} = $tmpprice || $price;

      $tmpprice = 40;
      if ($field->subfield("w")){
         $tmpprice = $field->subfield("w");
         $tmpprice =~ s/(\d+(\.[0-9]{2}))/$1/;
         $tmpprice =~ s/\$//g;
      }
      $replprice{$barcode} = $tmpprice;

      # SERIAL ENUM/CHRON

      if ($field->subfield("y")){
          $enumchron{$barcode} = $field->subfield("y");
      }

      # COPY NUMBER
    
      if ($field->subfield("c")){
          $copynum{$barcode} = $field->subfield("c");
          $copynum{$barcode} =~ s/\D//;
          $copynum{$barcode} =~ s/\.//;
          $copynum{$barcode} =~ s/ //;
      }

      # HOMEBRANCH/HOLDINGBRANCH
      # Everything is "QUIN".
          $homebranch{$barcode} = "QUIN";

      # ITEM CALL

      if ($field->subfield("f")){
          $itemcall{$barcode} = $field->subfield("f");
      }
      else {
          $itemcall{$barcode} = $bibcall;
      }
 
      #NOTE

      if ($field->subfield("7")){
          $itemnote{$barcode} = $field->subfield("7");
      }
      if ($field->subfield("n")){
          $itemnote{$barcode} .= " -- " if ($itemnote{$barcode});
          $itemnote{$barcode} = $field->subfield("n");
      }
      if ($field->subfield("m")){
          $itemnote{$barcode} .= " -- " if ($itemnote{$barcode});
          $itemnote{$barcode} = $field->subfield("m");
      }
      if ($field->subfield("h")){
          $itemnote{$barcode} .= " -- " if ($itemnote{$barcode});
          $itemnote{$barcode} = $field->subfield("h");
      }
      if ($field->subfield("r")){
          $itemnote{$barcode} .= " -- " if ($itemnote{$barcode});
          $itemnote{$barcode} = $field->subfield("r");
      }
      if ($field->subfield("i")){
          $pubnote{$barcode} = $field->subfield("7");
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
      $itmtag->update( "x" => $itemnote{$key} ) if ($itemnote{$key});
      $itmtag->update( "z" => $pubnote{$key} ) if ($pubnote{$key});
      $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
      $itmtag->update( "e" => $acqsource{$key} ) if ($acqsource{$key});
      $record->insert_grouped_field($itmtag);
   }

   print MARCFL $record->as_usmarc();
   $k++;
}
close MARCFL;

print "\n\nRESULTS BY CATEGORYCODE\n";
foreach my $kee (sort keys %types){
   print $kee.":   ".$types{$kee}."\n";
}
print "\n\n$k records processed.\n";


