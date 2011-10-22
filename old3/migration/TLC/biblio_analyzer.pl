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
use warnings;
use Data::Dumper;
use Getopt::Long;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
$|=1;
my $debug=0;

my $infile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
    'debug'    => \$debug,
);

if ($infile_name eq ''){
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
my %holdcodes;
my %subfields;
my $no_949=0;
my $no_holdcode=0;
my $no_barcode=0;
while () {
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);

   if (!$record->field("852")){
       $no_949++;
       next;
   }

   foreach my $field ($record->field("852")){
      if (!$field->subfield('p')){
          $no_barcode++;
          next;
      }
      if ($field->subfield("a")){
          $holdcodes{$field->subfield("a")}++;
          if ($field->subfield("a") =~ /\$/){
             
             $debug and print "\nproblem?\n";
             $debug and print Dumper($record);
          }
      }
      else {
          $no_holdcode++;
      }

      for my $subfield ($field->subfields()){
          my ($letter,undef) = @$subfield;
          $subfields{$letter}++;
      }
   }
}

print "\n$i records read\n";
print "\nRESULTS BY HOLDING CODE:\n";
foreach my $kee (sort keys %holdcodes){
   print $kee.":  ".$holdcodes{$kee}."\n";
}

print "\nSUBFIELDS APPEARING:\n";
foreach my $kee (sort keys %subfields){
   print $kee.":  ".$subfields{$kee}."\n";
}

print "\nCOUNTS OF PROBLEMS:\n";
print "NO HOLD CODE IN 949: $no_holdcode\nNO BARCODE IN 949: $no_barcode\nNO 949s: $no_949\n\n";

