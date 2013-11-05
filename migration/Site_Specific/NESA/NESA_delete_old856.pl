#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# 
# Modification log: (initial and date)
#   joy - modify for NESA -856 removal 9/6/12
#
#---------------------------------
#
# EXPECTS:
#   -input MARC file
#
# DOES:
#   -nothing
#
# CREATES:
#   -revised MARC file
#
# REPORTS:
#   -counts of records read, written, and modified

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
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename  = $NULL_STRING;
my $output_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'out=s'    => \$output_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();
my $setting = MARC::Charset::assume_encoding('utf-8');
my $modified_record   = 0;
my $subu;

open my $output_file,'>:utf8',$output_filename;

RECORD:
while () {
   my $record;
   eval { $record = $batch->next(); } ;
   if ($@) {
      print "Bogus record skipped.\n";
      next RECORD;
   }
   last RECORD unless ($record);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $modified_this = 0;

TAG:
   foreach my $thisfield ($record->field('856')) {
     $subu = $thisfield->subfield('u');
     
     next TAG if (!$subu);

     if ( $subu !~ /66.205.80.67/) {
       next TAG;
     }
$debug and print "$subu\n";

     if ($subu =~ /66.205.80.67/ ) {
          $record->delete_field($thisfield);
          $modified_this = 1;
     }
   } 

   if ($modified_this) {
      $modified_record++;
   }
   print {$output_file} $record->as_usmarc();
   $written++; 
}
close $input_file;
close $output_file;

print << "END_REPORT";

$i records read.
$written records written.
$modified_record records were changed.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
