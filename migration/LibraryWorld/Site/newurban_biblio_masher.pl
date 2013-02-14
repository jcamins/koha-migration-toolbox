#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -edited by Joy Nelson
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
my $shelfloc_map_name = "";
my %shelfloc_map;
my $itype_map_name = "";
my %itype_map;
my $drop_noitem = 0;
my $call1 = "";
my $call2 = "";
my $acquired = "";
my $enumeration = "";

GetOptions(
    'in=s'           => \$infile_name,
    'out=s'          => \$outfile_name,
    'branch=s'       => \$branch,
    'shelfloc_map=s' => \$shelfloc_map_name,
    'itype_map=s'    => \$itype_map_name,
    'drop_noitem'    => \$drop_noitem,
    'debug'          => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
if (($branch eq '')){
  print "Something's missing.\n";
  exit;
}

if ($shelfloc_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$shelfloc_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $shelfloc_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($itype_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$itype_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $itype_map{$data[0]} = $data[1];
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
my %itypecount;
my %loccount;
my %itype_942count;

while () {
   last if ($debug and $i > 99); 
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
       foreach my $dumpfield($record->field('952')){
          $record->delete_field($dumpfield);
       }
       foreach my $dumpfield($record->field('852')){
          $record->delete_field($dumpfield);
       }
       print $outfl $record->as_usmarc();
       $written++;
       next;
   }
   
   my $price = 0;

#   if ($record->subfield("020","c")){
#      $price = $record->subfield("020","c");
      #$price =~ s/\D\.]//;
#      $price =~ s/(\d+(\.[0-9]{2}))/$1/;
#      $price =~ s/\$//g;
#   }
#   else {
#      $price = 0;
#   }

#   if ($record->subfield('908','a')){
#      my $acquired=$record->subfield('908','a');
#   }
#   else {
#   $acquired="";
#   }

#comment this out...use 852 i instead
#   if ($record->subfield('362','a')){
#      my $enumeration=$record->subfield('362','a');
#   }
#   else {
#   $enumeration="";
#   }


   #itemtype
   my $elec_res='';
   my $item_type;
   my $raw_item_type = substr($record->leader(),6,2);
   if (exists($itype_map{$raw_item_type})){
      $item_type = $itype_map{$raw_item_type};
   } 
   else {
       $item_type = "UNKNOWN";
   }

   $elec_res = $record->subfield('245','h');
       if ( ($elec_res) && ($elec_res =~ /ectronic resource/ ))  {
           $item_type = 'EBOOK';
print "$elec_res\n";

       }


   my $keeper_itype;
   my %itype;
   my %homebranch;
   my %holdbranch;
   my %loc;
   my %acqdate;
   my %itmprice;
   my %copynum;
   my %itemcall;
   my %itemnote;
   my %enumchron;
   my $keep_this_record=0;
   my %voldesc;
   my %volnum;
   my %call1;
   my %call2;

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
      #branch
      $homebranch{$barcode}=$branch;
      $holdbranch{$barcode}=$branch;

      #copynumber  --CHECK THE FIELD FOR URBAN
      if ($field->subfield('t')) {
      $copynum{$barcode} = $field->subfield('t');
      }
      else { $copynum{$barcode}="";}

      #itemnotes  --CHECK THE FIELD FOR URBAN
      if ($field->subfield('z')) {
      $itemnote{$barcode} = $field->subfield('z');
      }
      else {$itemnote{$barcode}="";}

      #enumchron

#      if ($field->subfield('i')) {
#      $enumchron{$barcode} = $field->subfield('i');
#      }
#      else {$enumchron{$barcode}="";}
    
#      $enumchron{$barcode} = $enumeration;

      #callnumber
      if  ($field->subfield('i')) {
        $call2{$barcode}= $field->subfield('i');
      }
      else {
        $call2{$barcode} = " ";
      }

      if  ($field->subfield('h')) {
        $call1{$barcode}= $field->subfield('h');
      }
      else {
        $call1{$barcode} = " ";
      }
  
      $itemcall{$barcode} = $call1{$barcode}." ".$call2{$barcode};
      #$itemcall{$barcode} =~ s/^\s+//;    
      #$itemcall{$barcode} =~ s/\s+$//;    
      #$itemcall{$barcode} =~ s/\s+$//;    

      #itemprice
      if ($field->subfield('9')) {
         $itmprice{$barcode} =$field->subfield('9') ;
      }
      else {
         $itmprice{$barcode} = 0;
      }

      #acquisition date  -adjust date arrangement here???
      #$acqdate{$barcode} = $acquired;

      #shelvinglocation --CHECK THIS FIELD FOR URBAN
      my $shelflocation = $field->subfield('b') || " ";

      if (exists($shelfloc_map{$shelflocation})){
           $loc{$barcode} = $shelfloc_map{$shelflocation};
           }
      else {
           $loc{$barcode}=" ";
           }

      $loccount{$loc{$barcode}}++;

      #itemtype     
      $itype{$barcode} = $item_type;
      $keeper_itype=$itype{$barcode};
   }
 $itypecount{$keeper_itype}++;

#end 852 loop


   foreach my $dumpfield($record->field('9..')){
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
           "g" => $itmprice{$key},
           "2" => "ddc",
         );
         
         $itmtag->update( "c" => $loc{$key} ) if ($loc{$key});
         $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
         $itmtag->update( "t" => $copynum{$key} ) if ($copynum{$key});
         $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
         $itmtag->update( "h" => $enumchron{$key} ) if ($enumchron{$key});

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

close $codes;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n";
print "$no_852 biblios with no 852.\n$bad_852 852s missing barcode, so codes autogenerated.\n";

print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itypecount){
   print $kee.":   ".$itypecount{$kee}."\n";
}
print "\nKEEPER ITEM TYPES (942):\n";
foreach my $kee (sort keys %itype_942count){
   print $kee.":   ".$itype_942count{$kee}."\n";
}
print "\nSHELVING LOCATIONS:\n";
foreach my $kee (sort keys %loccount){
   print $kee.":   ".$loccount{$kee}."\n";
}
print "\n";

