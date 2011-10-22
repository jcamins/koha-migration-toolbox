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
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
my $i=0;
my $j=0;
my $no_952=0;
my $bad_952=0;
my %types;
my %statuses;
my %collcodes;
my %locations;
my %branches;

while () {
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   my $record = eval{ $batch->next(); };
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);

   if (!$record->field("952")){
       $no_952++;
       next;
   }

   foreach my $field ($record->field("952")){
      $j++;
    
      if ($field->subfield('a')){
         $branches{uc($field->subfield('a'))}++;
      }
      else{
         $branches{'NONE'}++;
      }
      if ($field->subfield('c')){
         $locations{uc($field->subfield('c'))}++;
      }

      if ($field->subfield('y')){
         $types{uc($field->subfield('y'))}++;
      }
      else {
         $types{'NONE'}++;
      }
      if ($field->subfield('8')){
         $collcodes{uc($field->subfield('8'))}++;
      }
   }
}

print "\n\n$i biblios read.\n$j items read.\n$no_952 biblios with no 952.\n$bad_952 952s missing barcode or itemtype.\n";
print "\nRESULTS BY ITEM TYPE\n";
foreach my $kee (sort keys %types){
   print $kee.":   ".$types{$kee}."\n";
}

print "\nRESULTS BY BRANCH\n";
foreach my $kee (sort keys %branches){
   print $kee.":   ".$branches{$kee}."\n";
}

print "\nRESULTS BY COLLECTION CODE\n";
foreach my $kee (sort keys %collcodes){
   print $kee.":   ".$collcodes{$kee}."\n";
}

print "\nRESULTS BY LOCATION CODE\n";
foreach my $kee (sort keys %locations){
   print $kee.":   ".$locations{$kee}."\n";
}
exit if (!$create);

open my $out,">$outfile_name";
print $out "# Branches \n";
foreach my $kee (sort keys %branches){
   print $out "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','NEW--$kee');\n";
}
print $out "# Shelving Locations\n";
foreach my $kee (sort keys %locations){
   print $out "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','NEW--$kee');\n";
}
print $out "# Item Types\n";
foreach my $kee (sort keys %types){
   print $out "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','NEW--$kee');\n";
}
print $out "# Collection Codes\n";
foreach my $kee (sort keys %collcodes){
   print $out "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','NEW--$kee');\n";
}

close $out;
