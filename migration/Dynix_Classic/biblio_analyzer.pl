#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -nothing

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = "";

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $file_handle = IO::File->new($input_filename);
my $batch = MARC::Batch->new('USMARC',$file_handle);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');

my %itemtypes;
my %branches;
my %locations;
my %collcodes;
my %subfields;
my $no_949=0;
my $no_barcode = 0;

RECORD:
while () {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $record = $batch->next();
   if ($@){
      print "Bogusness skipped\n";
      next RECORD;
   }
   last RECORD unless ($record);

   if (!$record->field("949")){
       $no_949++;
       next RECORD;
   }

FIELD:
   foreach my $field ($record->field("949")){
      $j++;
      if (!$field->subfield('b')){
          $no_barcode++;
          next FIELD;
      }
      if ($field->subfield("t")){
          $itemtypes{$field->subfield("t")}++;
      }
      if ($field->subfield("m")){
          $branches{$field->subfield("m")}++;
      }
      if ($field->subfield("n")){
          $locations{$field->subfield("n")}++;
      }
      if ($field->subfield("c")){
          $collcodes{$field->subfield("c")}++;
      }
      for my $subfield ($field->subfields()){
          my ($letter,undef) = @$subfield;
          $subfields{$letter}++;
      }
   }
}

print "\n$i records read\n$j 949 fields found.\n";
print "\nCOUNTS OF PROBLEMS:\n";
print "NO BARCODE IN 949: $no_barcode\nNO 949s: $no_949\n\n";
print "\nRESULTS BY ITEM TYPE:\n";
foreach my $kee (sort keys %itemtypes){
   print $kee.":  ".$itemtypes{$kee}."\n";
}
print "\nRESULTS BY BRANCH:\n";
foreach my $kee (sort keys %branches){
   print $kee.":  ".$branches{$kee}."\n";
}
print "\nRESULTS BY LOCATION:\n";
foreach my $kee (sort keys %locations){
   print $kee.":  ".$locations{$kee}."\n";
}
print "\nRESULTS BY COLLECTION CODE:\n";
foreach my $kee (sort keys %collcodes){
   print $kee.":  ".$collcodes{$kee}."\n";
}
print "\nSUBFIELDS APPEARING:\n";
foreach my $kee (sort keys %subfields){
   print $kee.":  ".$subfields{$kee}."\n";
}

exit;
