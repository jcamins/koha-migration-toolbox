#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
use Text::CSV_XS;
$|=1;
my $debug=0;

my $infile_name = "";


GetOptions(
    'in=s'          => \$infile_name,
    'debug'         => \$debug,
);

if ($infile_name eq ''){
  print "Something's missing.\n";
  exit;
}

my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
my $i=0;
my $j=0;
my $no_940=0;
my %category_counts;
my %blockcode_counts;
my %deptcode_counts;

RECORD:
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

   if (!$record->field("940")){
       $no_940++;
       next RECORD;
   }
  
   my $field = $record->field("940");
   $category_counts{$field->subfield('b')}++;
   $blockcode_counts{$field->subfield('e')}++;
   $deptcode_counts{$field->subfield('q')}++;
}
 
close $infl;

print "\n\n$i patrons read.\n$no_940 patron recs with no 940.\n";
print "\nCATEGORY COUNTS\n";
foreach my $kee (sort keys %category_counts){
   print "$kee:  $category_counts{$kee}\n";
}
print "\nBLOCKCODE COUNTS\n";
foreach my $kee (sort keys %blockcode_counts){
   print "$kee:  $blockcode_counts{$kee}\n";
}
print "\nDEPTCODE COUNTS\n";
foreach my $kee (sort keys %deptcode_counts){
   print "$kee:  $deptcode_counts{$kee}\n";
}

