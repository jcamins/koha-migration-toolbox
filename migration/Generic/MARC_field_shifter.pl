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
#   -authority MARC file
#
# DOES:
#   -nothing
#
# CREATES:
#   -repaired authority MARC file
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
    'map=s'         => \@maps,
    'debug'         => \$debug,
);

if (($input_filename eq '') || ($output_filename eq '') || (!@maps)) {
  print "Something's missing.\n";
  exit;
}

my $written = 0;
my $updated = 0;

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
   my $this_record_updated=0;
   eval{ $this_record = $batch->next(); };
   if ($EVAL_ERROR){
      print "Bogusness skipped\n";
      next RECORD;
   }
   last RECORD unless ($this_record);
   $i++;
   print '.'    unless $i % 10;;
   print "\r$i" unless $i % 100;

   foreach my $map (@maps) {
      my ($oldtag,$newtag) = split ':', $map;
      if (!$oldtag || !$newtag) {
         croak ("Bad map!  ($map)");
      }
      if ($this_record->field($oldtag)) {
          my $oldfield = $this_record->field($oldtag);
          my $newfield = MARC::Field->new($newtag,' ',' ', '9' => 1);

          $newfield->update( ind1 => $oldfield->indicator(1) );
          $newfield->update( ind2 => $oldfield->indicator(2) );
          foreach my $sub ($oldfield->subfields()) {
             my ($code,$val) = @$sub;
             $newfield->update( $code => $val );
          }
          $newfield->delete_subfield( code => '9' );
          $this_record->insert_grouped_field($newfield);
          $this_record->delete_field($oldfield);
          $this_record_updated = 1;
       }
   }
   if ($this_record_updated) {
      $updated++;
   }

   print {$out_fh} $this_record->as_usmarc();
   $written++;
}
close $out_fh;
close $in_fh;

print << "END_REPORT";


$i records read.
$updated records modified.
$written records written.
END_REPORT
