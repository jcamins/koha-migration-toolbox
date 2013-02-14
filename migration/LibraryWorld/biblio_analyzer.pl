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
my $written=0;
my $no_852=0;
my $bad_852_nobarcode=0;
my $bad_852_noholdcode=0;
my %branch_counts;
my %itype_counts;
my %loc_counts;
my %status_counts;
my %collname_counts;

RECORD:
while () {
   last if ($debug and $i > 35000);
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
       next RECORD;
   }
   my $itype = substr($record->leader(),6 ,2);
$itype_counts{$itype}++;
  
ITMRECORD: 
   foreach my $field ($record->field("852")){
      $j++;
      if (!$field->subfield('p')){
         $bad_852_nobarcode++;
         next ITMRECORD;
      }
      if (!$field->subfield('b')){
         $bad_852_noholdcode++;
         next ITMRECORD;
      }
print "$field->subfield('j')\n";
      $branch_counts{$field->subfield('b')}++;
      $loc_counts{$field->subfield('k')}++;
      $status_counts{$field->subfield('a')}++ if ($field->subfield('a'));
      $collname_counts{$field->subfield('j')}++;
#      $itype_counts{$itype}++;
   }
}
 
close $infl;

print "\n\n$i biblios read.\n$j items read.\n$no_852 biblios with no 852.\n$bad_852_nobarcode 852s missing barcode.\n$bad_852_noholdcode 852s missing holding code.\n";
print "BRANCH COUNTS\n";
foreach my $kee (sort keys %branch_counts){
   print "$kee:  $branch_counts{$kee}\n";
}
print "\nITEM TYPE COUNTS\n";
foreach my $kee (sort keys %itype_counts){
   print "$kee:  $itype_counts{$kee}\n";
}
print "\nLOCATION COUNTS\n";
foreach my $kee (sort keys %loc_counts){
   print "$kee:  $loc_counts{$kee}\n";
}
print "\nSTATUS COUNTS\n";
foreach my $kee (sort keys %status_counts){
   print "$kee:  $status_counts{$kee}\n";
}
print "\nCOLL NAME COUNTS\n";
foreach my $kee (sort keys %collname_counts){
   print "$kee:  $collname_counts{$kee}\n";
}

