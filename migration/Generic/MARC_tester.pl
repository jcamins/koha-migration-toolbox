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
#   -repaired MARC file
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
my $broken_filename = '/dev/null';

GetOptions(
    'in=s'          => \$input_filename,
    'out=s'         => \$output_filename,
    'err=s'         => \$broken_filename,
    'debug'         => \$debug,
);

if (($input_filename eq '') || ($output_filename eq '') ) {
  print "Something's missing.\n";
  exit;
}

my $written = 0;
my $updated = 0;
my $problem = 0;

my $in_fh  = IO::File->new($input_filename);
my $batch = MARC::Batch->new('USMARC',$in_fh);
$batch->warnings_off();
$batch->strict_off();
my $iggy    = MARC::Charset::ignore_errors(1);
my $iggy2   = MARC::Batch::strict_off();
my $setting = MARC::Charset::assume_encoding('utf8');
open my $out_fh,">:utf8",$output_filename;
open my $err_fh,">:utf8",$broken_filename;

RECORD:
while () {
   last RECORD if ($debug and $i > 99);
   my $this_record;
   my $this_record_updated=0;
   eval{ $this_record = $batch->next(); };
   if ($EVAL_ERROR){
      print "\nBogusness skipped: $EVAL_ERROR\n";
      print {$err_fh} $this_record->as_usmarc();
      $problem++;
      next RECORD;
   }
   last RECORD unless ($this_record);
   $i++;
   print '.'    unless $i % 10;;
   print "\r$i" unless $i % 100;

   print {$out_fh} $this_record->as_usmarc();
   $written++;
}
close $out_fh;
close $in_fh;

print << "END_REPORT";


$i records read.
$written records written.
$problem problem records not written.
END_REPORT
