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

GetOptions(
    'in=s'          => \$infile_name,
    'debug'         => \$debug,
);

if (($infile_name eq '')){
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
my $no_852=0;
my $bad_852=0;
my %subfields;
my %holdcodes;

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

   if (!$record->field("852")){
       $no_852++;
       next;
   }

   foreach my $field ($record->field("852")){
      $j++;
      if (!$field->subfield('b') || !$field->subfield('p')){
         $bad_852++;
         next;
      }
      $holdcodes{$field->subfield('b')}++;

      for my $subfield ($field->subfields()){
          my ($letter,undef) = @$subfield;
          $subfields{$letter}++;
      }
   }
}

print "\n\n$i biblios read.\n$j items read.\n$no_852 biblios with no 852.\n$bad_852 852s missing barcode or itemtype.\n";
print "\nRESULTS BY HOLDING CODE\n";
foreach my $kee (sort keys %holdcodes){
   print $kee.":   ".$holdcodes{$kee}."\n";
}

print "\nSUBFIELDS APPEARING:\n";
foreach my $kee (sort keys %subfields){
   print $kee.":  ".$subfields{$kee}."\n";
}

