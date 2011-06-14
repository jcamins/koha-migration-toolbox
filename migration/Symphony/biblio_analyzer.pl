#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
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
$|=1;
my $debug=0;

my $infile_name = "";
my $reverse_cats = 0;
my $outfile_name = "";
my $create = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'create'        => \$create,
    'debug'         => \$debug,
    'reverse_cats'  => \$reverse_cats,
);

if (($infile_name eq '') || ($create && $outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $fh = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$fh);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
my $i=0;
my $j=0;
my $no_999=0;
my $bad_999=0;
my %libraries;
my %holdcodes;
my %locations;
my %types;
my %schema;
my %cat1;
my %cat2;
my %collcode;
my %collcode_desc;

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

   if (!$record->field("999")){
       $no_999++;
       next;
   }

   foreach my $field ($record->field("999")){
      $j++;
      if (!$field->subfield('i') || !$field->subfield('t')){
         $bad_999++;
         next;
      }
      $schema{$field->subfield('w')}++;

      if ($field->subfield('m')){
         $libraries{$field->subfield('m')}++;
      } 
      else {
         $libraries{'NONE'}++;
      }
      if ($field->subfield('h')){
         $holdcodes{$field->subfield('h')}++;
      } 
      else {
         $holdcodes{'NONE'}++;
      }
      if ($field->subfield('l')){
         $locations{$field->subfield('l')}++;
      } 
      else {
         $locations{'NONE'}++;
      }
      if ($field->subfield('t')){
         $types{$field->subfield('t')}++;
      } 
      else {
         $types{'NONE'}++;
      }
      if ($field->subfield('x')){
         $cat1{$field->subfield('x')}++;
      } 
      else {
         $cat1{'NONE'}++;
      }
      if ($field->subfield('z')){
         $cat2{$field->subfield('z')}++;
      } 
      else {
         $cat2{'NONE'}++;
      }
      my $cat1 = $field->subfield('x');
      my $cat2 = $field->subfield('z');
      if ($reverse_cats){
         $cat1 = $field->subfield('z');
         $cat2 = $field->subfield('x');
      }
      my $part1 = $cat1 ? substr($cat1,0,2) : "__";
      my $part2 = $cat2 ? substr($cat2,0,8) : "________";
      my $desc1 = $cat1 ? $cat1 : "NULL";
      my $desc2 = $cat2 ? $cat2 : "NULL";
      my $finalcode = $part1.$part2;
      my $finaldesc = $desc1."/".$desc2;
      $collcode{$finalcode}++;
      $collcode_desc{$finalcode} = $finaldesc;
   }
}

print "\n\n$i biblios read.\n$j items read.\n$no_999 biblios with no 999.\n$bad_999 999s missing barcode or itemtype.\n";
print "\nRESULTS BY LIBRARY\n";
foreach my $kee (sort keys %libraries){
   print $kee.":   ".$libraries{$kee}."\n";
}

print "\nRESULTS BY LOCATION CODE\n";
foreach my $kee (sort keys %locations){
   print $kee.":   ".$locations{$kee}."\n";
}

print "\nRESULTS BY HOLDING CODE\n";
foreach my $kee (sort keys %holdcodes){
   print $kee.":   ".$holdcodes{$kee}."\n";
}

print "\nRESULTS BY ITEM TYPE\n";
foreach my $kee (sort keys %types){
   print $kee.":   ".$types{$kee}."\n";
}

print "\nRESULTS BY CAT1\n";
foreach my $kee (sort keys %cat1){
   print $kee.":   ".$cat1{$kee}."\n";
}

print "\nRESULTS BY CAT2\n";
foreach my $kee (sort keys %cat2){
   print $kee.":   ".$cat2{$kee}."\n";
}

print "\nRESULTS BY CALL SCHEMA\n";
foreach my $kee (sort keys %schema){
   print $kee.":   ".$schema{$kee}."\n";
}

print "\nRESULTS BY COLLECTION CODE\n";
foreach my $kee (sort keys %collcode){
   print $kee.":   ".$collcode{$kee}."  (".$collcode_desc{$kee}.")\n";
}

exit if (!$create);

open my $outfl,">$outfile_name";
print $outfl "# Branches\n";
foreach my $kee (sort keys %libraries){
   print $outfl "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print $outfl "# Locations\n";
foreach my $kee (sort keys %locations){
   if ($kee ne "NONE"){
      print $outfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','$kee');\n";
   }
}
print $outfl "# Item Types\n";
foreach my $kee (sort keys %types){
   print $outfl "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','$kee');\n";
}
print $outfl "# Collection Codes\n";
foreach my $kee (sort keys %collcode){
   if ($collcode_desc{$kee} ne "NULL/NULL"){
      print $outfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('COLL','$kee','$collcode_desc{$kee}');\n";
   }
}
close $outfl;
