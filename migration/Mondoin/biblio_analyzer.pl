#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# edited: Joy Nelson
#---------------------------------

use autodie;
use warnings;
use strict;
use Getopt::Long;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $create = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'create'        => \$create,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($create && $outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $fh = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$fh);
$batch->warnings_off();
$batch->strict_off();
#my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf-8');
my $i=0;
my $j=0;
my $no_852=0;
my $bad_852=0;
my %branch;
my %collcode;
my %loccode;
my %categorycode;
my %medium;
my %conserv;
my %format;
my %state;
my %status;

RECORD:
while () {
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
my $record;

   eval {$record = $batch->next();};
   if ($@){
      print "Bogusness skipped\n";
      next RECORD;
   }
   last RECORD unless ($record);

   if (!$record->field("852")){
       $no_852++;
       next;
   }

   foreach my $field ($record->field("852")){
      $j++;
      if ( !$field->subfield('p') || !$field->subfield('h') ) {
         $bad_852++;
         next;
      }
      if ($field->subfield('a')){
         $branch{$field->subfield('a')}++;
      }
      else {
         $branch{'NONE'}++;
      }

      if ($field->subfield('b')){
         $loccode{$field->subfield('b')}++;
      }
      else {
         $loccode{'NONE'}++;
      }

      if ($field->subfield('c')){
         $categorycode{$field->subfield('c')}++;
      }
      else {
         $categorycode{'NONE'}++;
      }

      if ($field->subfield('k')){
         $medium{$field->subfield('k')}++;
      }
      else {
         $medium{'NONE'}++;
      }

      if ($field->subfield('l')){
         $format{$field->subfield('l')}++;
      }
      else {
         $format{'NONE'}++;
      }

      if ($field->subfield('m')){
         $conserv{$field->subfield('m')}++;
      }
      else {
         $conserv{'NONE'}++;
      }

      if ($field->subfield('n')){
         $state{$field->subfield('n')}++;
      }
      else {
         $state{'NONE'}++;
      }

      if ($field->subfield('6')){
         $status{$field->subfield('6')}++;
      }
      else {
         $status{'NONE'}++;
      }

      if ($field->subfield('3')){
         $collcode{$field->subfield('3')}++;
      } 
      else {
         $collcode{'NONE'}++;
      }


   }
}

print "\n\n$i biblios read.\n$j items read.\n$no_852 biblios with no 852.\n$bad_852 852s missing barcode or callnumber.\n";

print "\nRESULTS BY branch\n";
foreach my $kee (sort keys %branch){
   print $kee.":   ".$branch{$kee}."\n";
}
print "\nRESULTS BY loccode\n";
foreach my $kee (sort keys %loccode){
   print $kee.":   ".$loccode{$kee}."\n";
}
print "\nRESULTS BY categorycode\n";
foreach my $kee (sort keys %categorycode){
   print $kee.":   ".$categorycode{$kee}."\n";
}
print "\nRESULTS BY medium\n";
foreach my $kee (sort keys %medium){
   print $kee.":   ".$medium{$kee}."\n";
}
print "\nRESULTS BY conserv\n";
foreach my $kee (sort keys %conserv){
   print $kee.":   ".$conserv{$kee}."\n";
}
print "\nRESULTS BY format\n";
foreach my $kee (sort keys %format){
   print $kee.":   ".$format{$kee}."\n";
}

print "\nRESULTS BY state\n";
foreach my $kee (sort keys %state){
   print $kee.":   ".$state{$kee}."\n";
}
print "\nRESULTS BY collection code\n";
foreach my $kee (sort keys %collcode){
   print $kee.":   ".$collcode{$kee}."\n";
}

print "\nRESULTS BY status\n";
foreach my $kee (sort keys %status){
   print $kee.":   ".$status{$kee}."\n";
}

exit if (!$create);

open my $outfl,">$outfile_name";

print $outfl "# loccode\n";
foreach my $kee (sort keys %loccode){
   print $outfl "INSERT INTO authorised_values (category,authorised_value, lib) VALUES ('LOC','$kee','$kee');\n";
}
print $outfl "# Collection Codes\n";
foreach my $kee (sort keys %collcode){
      print $outfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('COLL','$kee','$collcode{$kee}');\n";
}
close $outfl;

