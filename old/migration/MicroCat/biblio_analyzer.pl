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
my %locations;
my %subfields;
my $no_090=0;
my $no_holdcode=0;
my $no_barcode=0;
my $ranged_barcode=0;
my %ranged_barcodes;

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

   if (!$record->field("090")){
       $no_090++;
       next;
   }

   foreach my $field ($record->field("090")){
      if (!$field->subfield('e')){
          $no_barcode++;
      }
      else {
         if ($field->subfield('e') =~ /[,-]/){
            $ranged_barcode++;
            $ranged_barcodes{$field->subfield('e')." ".$field->subfield('d')}++;
         }
      }
      $locations{$field->subfield('b')}++; 
      if ($field->subfield('f')){
         $holdcodes{$field->subfield('f')}++;
      }
      for my $subfield ($field->subfields()){
          my ($letter,undef) = @$subfield;
          $subfields{$letter}++;
      }
   }
}

print "\n$i records read\n";
print "\nRESULTS BY LOCATION CODE:\n";
foreach my $kee (sort keys %locations){
   print $kee.":  ".$locations{$kee}."\n";
}

print "\nRESULTS BY HOLDING CODE:\n";
foreach my $kee (sort keys %holdcodes){
   print $kee.":  ".$holdcodes{$kee}."\n";
}

print "\nSUBFIELDS APPEARING:\n";
foreach my $kee (sort keys %subfields){
   print $kee.":  ".$subfields{$kee}."\n";
}

print "\nCOUNTS OF PROBLEMS:\n";
print "NO BARCODE IN 090: $no_barcode\nNO 090s: $no_090\nRANGED BARCODES: $ranged_barcode\n\n";
foreach my $kee (sort keys %ranged_barcodes){
   print $kee.":  ".$ranged_barcodes{$kee}."\n";
}

