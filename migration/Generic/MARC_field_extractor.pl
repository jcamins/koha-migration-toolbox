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
#   -MARC file
#
# DOES:
#   -nothing
#
# CREATES:
#   -CSV with barcode and datelastborrowed (NCRL)
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
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
use Text::CSV_XS;

local $OUTPUT_AUTOFLUSH = 1;

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;

my $input_filename  = "";
my $output_filename = "";
my @maps;

GetOptions(
    'in=s'          => \$input_filename,
    'out=s'         => \$output_filename,
    'debug'         => \$debug,
);

if (($input_filename eq '') || ($output_filename eq '')) {
  print "Something's missing.\n";
  exit;
}

my $written = 0;

my $in_fh  = IO::File->new($input_filename);
my $batch = MARC::Batch->new('USMARC',$in_fh);
$batch->warnings_off();
$batch->strict_off();
my $iggy    = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
open my $out_fh,">:utf8",$output_filename;

RECORD:
while () {
   last RECORD if ($debug and $i > 99);
   my $this_record;
   eval{ $this_record = $batch->next(); };
   if ($EVAL_ERROR){
      print "Bogusness skipped\n";
      next RECORD;
   }
   last RECORD unless ($this_record);
   $i++;
   print '.'    unless $i % 10;;
   print "\r$i" unless $i % 100;

FIELD:
   foreach my $field ($this_record->field('949')) {
      my $barcode=$field->subfield('b');
      my $date=$field->subfield('o');
      next FIELD if (!$barcode || !$date);
      print {$out_fh} "$barcode,"._process_date($date)."\n";
      $written++;
   }
}
close $out_fh;
close $in_fh;

print << "END_REPORT";


$i records read.
$written records written.
END_REPORT

exit;

sub _process_date {
   my $data=shift;

   my %months =(
                JAN => 1, FEB => 2,  MAR => 3,  APR => 4,
                MAY => 5, JUN => 6,  JUL => 7,  AUG => 8,
                SEP => 9, OCT => 10, NOV => 11, DEC => 12
               );
   $data = uc $data;
   $data =~ s/,//;
   my ($monthstr,$day,$year) = split(/ /,$data);
   if ($monthstr && $day && $year){
      $data = sprintf "%4d-%02d-%02d",$year,$months{$monthstr},$day;
   }
   else {
      $data= q{};
   }
   return $data;
}

