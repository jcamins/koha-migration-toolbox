#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -original script unknown 
#  edited by Joy Nelson
#     -10/10/2012
#  
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $branch = "";
my $shelfloc_map_name1 = "";
my %shelfloc_map1;
my $itype_map_name1 = "";
my %itype_map1;
my $shelfloc_map_name2 = "";
my %shelfloc_map2;
my $itype_map_name2 = "";
my %itype_map2;
my $drop_noitem = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'branch=s'          => \$branch,
    'shelfloc_map1=s'    => \$shelfloc_map_name1,
    'itype_map1=s'       => \$itype_map_name1,
    'shelfloc_map2=s'    => \$shelfloc_map_name2,
    'itype_map2=s'       => \$itype_map_name2,
    'drop_noitem'   => \$drop_noitem,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
if (($branch eq '')){
  print "Something's missing.\n";
  exit;
}

if ($shelfloc_map_name1){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$shelfloc_map_name1";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $shelfloc_map1{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($itype_map_name1){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$itype_map_name1";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $itype_map1{$data[0]} = $data[1];
   }
   close $mapfile;
}
if ($itype_map_name2){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$itype_map_name2";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $itype_map2{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($shelfloc_map_name2){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$shelfloc_map_name2";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $shelfloc_map2{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
open my $outfl,">:utf8",$outfile_name;

my $i=0;
my $j=0;
my $written=0;
my $no_852=0;
my $bad_852=0;
my %branchcount;
my %itypecount;
my %loccount;
my %itype_942count;

while () {
   last if ($debug and $i > 9999);
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);

   if (!$record->field("852")){
       $no_852++;
       next if ($drop_noitem);
       foreach my $dumpfield($record->field('942')){
          $record->delete_field($dumpfield);
       }
       foreach my $dumpfield($record->field('952')){
          $record->delete_field($dumpfield);
       }
       foreach my $dumpfield($record->field('998')){
          $record->delete_field($dumpfield);
       }
       foreach my $dumpfield($record->field('999')){
          $record->delete_field($dumpfield);
       }

       print $outfl $record->as_usmarc();
       $written++;
       next;
   }
   
   my $price = 0;
   my %homebranch;
   my %holdbranch;
   my %itype;
   my %location;
   my %notforloan;
   my %collcode;
   my %acqdate;
   my %acqsource;
   my %seendate;
   my %item_hidden_note;
   my %itmprice;
   my %replprice;
   my %copynum;
   my %itemcall;
   my %itemnote;
   my %issues;
   my %enumchron;
   my $keeper_itype;
   my $keep_this_record=0;
   my %voldesc;
   my %volnum;
   my $j_value = '';
   my $i_value = '';
   my $collection;
   my $ctitemtype;
   my $ctcollcode;
   my $ctstatus;
   my %staffnote;   
   my %loststatus;
   my %holdstatus;
   my %loanstatus;
   my %checkouts;
   my %renewals;
   my %holds;
   my $circsub;
   my $stats;
   my @circpieces;
   my @statpieces;

   foreach my $field ($record->field("852")){
      $j++;
      my $barcode;
      if ($field->subfield('p')){
         $barcode= $field->subfield('p');
      }
      else{
         $bad_852++;
         $barcode="AUTO".sprintf("%05d",$i)."-".$j;
      }

      #circstats
      $circsub =  $field->subfield('9');
      @circpieces = split (/`/, $circsub);
      $stats = @circpieces[20];
      @statpieces = split (/\^/, $stats);
#$debug and print "circ stats $stats\n";
#$debug and print "OUT: $statpieces[0]  RENEW: $statpieces[1]  HOLD: $statpieces[2]\n";
      $checkouts{$barcode} = $statpieces[0] || 0;
      $renewals{$barcode} = $statpieces[1] || 0;
      $holds{$barcode} = $statpieces[2] || 0;
#$debug and print "$checkouts{$barcode}, $renewals{$barcode}, $holds{$barcode}\n";

      #copynumber
      $copynum{$barcode} = $field->subfield('t');

      #callnumber
      $itemcall{$barcode} = $field->subfield('h') || " ";
      $itemcall{$barcode} =~ s/^\s+//;    
      $itemcall{$barcode} =~ s/\s+$//;    
      $itemcall{$barcode} =~ s/\s+$//;    

      $ctitemtype=$field->subfield('d');
        if (exists($itype_map1{$ctitemtype})){
            $itype{$barcode} = $itype_map1{$ctitemtype};
            $location{$barcode} = $shelfloc_map1{$ctitemtype};
        }

      $ctcollcode=$field->subfield('b');
        if (exists($itype_map2{$ctcollcode})){
            $itype{$barcode} = $itype_map2{$ctcollcode};
            $location{$barcode} = $shelfloc_map2{$ctcollcode};
        }

#add special rules on status
      $ctstatus = $field->subfield('o');
      if ($ctstatus eq 'bindery' ) {
          $location{$barcode} = 'BINDERY';
          $itype{$barcode} = 'BOOKUN';
          }
      if ($ctstatus eq 'tech serv' ) {  #check this ctstatus value
          $location{$barcode} = 'OFFICE';
          $itype{$barcode} = 'BOOKUN';
          }
      if ($ctstatus eq 'IN PROCESS' ) {   #check this ctstatus value
          $location{$barcode} = 'OFFICE';
          $itype{$barcode} = 'BOOKUN';
          }

#other special rules here....
if ($ctitemtype eq 'Non-circulating'  && $ctcollcode eq 'AV' ) {
$itype{$barcode} = 'DVDNC';
$location{$barcode} = 'AVRES';
}
if ($ctitemtype eq 'Two Weeks'  && substr($itemcall{$barcode},0,3) eq 'FLB' ) {
$itype{$barcode} = 'BOOK';
$location{$barcode} = 'FOREIGNLANG';
}
if ($ctitemtype eq 'Non-circulating'  && substr($itemcall{$barcode},0,3) eq 'FLB' ) {
$itype{$barcode} = 'BOOKNC';
$location{$barcode} = 'FOREIGNLANGRES';
}
if ($ctitemtype eq 'Non-circulating'  && $ctcollcode eq 'Journal' ) {
$itype{$barcode} = 'JOURNAL';
$location{$barcode} = 'JOURNAL';
}
if ($ctstatus eq 'tech serv'  && $ctcollcode eq 'AV' ) {
$itype{$barcode} = 'DVDNC';
$location{$barcode} = 'OFFICE';
}
if ( ($ctstatus eq 'tech serv' || $ctstatus eq 'IN PROCESS')  && $ctitemtype eq 'One Week' ) {
$itype{$barcode} = 'DVDNC';
$location{$barcode} = 'OFFICE';
}
if ( ($ctstatus eq 'tech serv' || $ctstatus eq 'IN PROCESS')  && $ctcollcode eq 'Archives' ) {
$itype{$barcode} = 'ARCHIVE';
$location{$barcode} = 'OFFICE';
}

#LOST
if ( ($ctstatus eq 'lost') || ($ctstatus eq 'missing') ) {
  $loststatus{$barcode} = 1;
}


#HOLD  - NO HOLD FIELD IN ITEMS FOR THIS
#if ($ctstatus eq 'on hold') {
#  $holdstatus{$barcode} = 1;   #check this value
#}
#LOAN   -THIS WILL POPULATE WHEN CIRC IS LOADED AND ITEMS MODIFIED
#if ($ctstatus eq 'on loan') {
#  $loanstatus{$barcode} = DATE FIELD FROM $9??;  
#}

      $homebranch{$barcode} = $branch;
      $branchcount{$homebranch{$barcode}}++;
      $holdbranch{$barcode} = $branch;

      $keeper_itype=$itype{$barcode};
      $loccount{$location{$barcode}}++ ;

      $itemnote{$barcode}=$field->subfield('z') || "";
      $staffnote{$barcode}=$field->subfield('x') || "";

#add volume number  (not VHS)?
#add $f edition  ?


    }
#end 852 loop


   foreach my $dumpfield($record->field('99.')){
      $record->delete_field($dumpfield);
   }
   foreach my $dumpfield($record->field('942')){
      $record->delete_field($dumpfield);
   }
   foreach my $dumpfield($record->field('952')){
      $record->delete_field($dumpfield);
   }
   foreach my $dumpfield($record->field('852')){
      $record->delete_field($dumpfield);
   }
   if ($keeper_itype){
      my $tag942=MARC::Field->new("942"," "," ", "c" => $keeper_itype);
      $record->insert_grouped_field($tag942);
      if ($keeper_itype ne 'DUMP'){
         $itype_942count{$keeper_itype}++;
         $keep_this_record=1;
      }
   }

   foreach my $key (sort keys %homebranch){

      if ($itype{$key} ne 'DUMP'){
         $itypecount{$itype{$key}}++;
         my $itmtag=MARC::Field->new("952"," "," ",
           "p" => $key,
           "a" => $homebranch{$key},
           "b" => $holdbranch{$key},
           "o" => $itemcall{$key},
           "y" => $itype{$key},
#           "g" => $itmprice{$key},
#           "v" => $replprice{$key},
           "l" => $checkouts{$key},
           "m" => $renewals{$key},
           "n" => $holds{$key},
           "2" => "ddc",
         );
         
         $itmtag->update( "c" => $location{$key} ) if ($location{$key});
#         $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
#         $itmtag->update( "e" => $acqsource{$key} ) if ($acqsource{$key});
#         $itmtag->update( "r" => $seendate{$key} ) if ($seendate{$key});
         $itmtag->update( "x" => $staffnote{$key} ) if ($staffnote{$key});
#         $itmtag->update( "8" => $collcode{$key} ) if ($collcode{$key});
         $itmtag->update( "t" => $copynum{$key} ) if ($copynum{$key});
         $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
#         $itmtag->update( "l" => $issues{$key} ) if ($issues{$key});
#         $itmtag->update( "h" => $enumchron{$key} ) if ($enumchron{$key});
#         $itmtag->update( "7" => $notforloan{$key} ) if ($notforloan{$key});
         $itmtag->update( "1" => $loststatus{$key} ) if ($loststatus{$key});
             
         $record->insert_grouped_field($itmtag);
         $keep_this_record=1;
      }
   }

   if ($keep_this_record){
      print $outfl $record->as_usmarc();
      $written++;
   }
}
close $infl;
close $outfl;

open my $codes,">","biblio_codes.sql";
print $codes "# Branches\n";
foreach my $kee (sort keys %branchcount){
   print $codes "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print $codes "# Locations\n";
foreach my $kee (sort keys %loccount){
   if ($kee ne "NONE"){
      print $codes "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','$kee');\n";
   }
}
print $codes "# Item Types\n";
foreach my $kee (sort keys %itypecount){
   print $codes "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','$kee');\n";
}
#print $codes "# Collection Codes\n";
#foreach my $kee (sort keys %collcodecount){
#   print $codes "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','$kee');\n";
#}
close $codes;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n";
print "$no_852 biblios with no 852.\n$bad_852 852s missing barcode, so codes autogenerated.\n";
print "\nBRANCHES:\n";
foreach my $kee (sort keys %branchcount){
   print $kee.":   ".$branchcount{$kee}."\n";
}
print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itypecount){
   print $kee.":   ".$itypecount{$kee}."\n";
}
print "\nITEM TYPES (942):\n";
foreach my $kee (sort keys %itype_942count){
   print $kee.":   ".$itype_942count{$kee}."\n";
}
print "\nSHELVING LOCATIONS:\n";
foreach my $kee (sort keys %loccount){
   print $kee.":   ".$loccount{$kee}."\n";
}
#print "\nCOLLECTION CODES\n";
#foreach my $kee (sort keys %collcodecount){
#   print $kee.":   ".$collcodecount{$kee}."\n";
#}
print "\n";

