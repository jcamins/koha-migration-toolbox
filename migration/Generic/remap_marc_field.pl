#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# 
# Modification log: (initial and date)
#
#---------------------------------
#
# EXPECTS:
#   -input MARC file
#   -csv map of what to change
#   -field to remap
#
# DOES:
#   -nothing
#
# CREATES:
#   -revised MARC file
#
# REPORTS:
#   -counts of records read, written, and modified
#   -counts of contents of field

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
my $field_string    = $NULL_STRING;
my $map_filename    = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'out=s'    => \$output_filename,
    'tag=s'    => \$field_string,
    'map=s'    => \$map_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$output_filename,$field_string,$map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %data_map;
if ($map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$map_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $data_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $tag = substr($field_string,0,3);
my $sub = substr($field_string,3);

my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();
my $setting = MARC::Charset::assume_encoding('utf-8');
my %tally;
my $modified_subfield = 0;
my $modified_record   = 0;
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
   foreach my $thisfield ($record->field($tag)) {
      if ($thisfield->subfield($sub)) {
         my $field_data = $thisfield->subfield($sub);
         if (exists $data_map{$field_data}) {
            $thisfield->update( $sub => $data_map{$field_data} );
         }
         if ($thisfield->subfield($sub) eq 'NULL') { 
            $thisfield->delete_subfield( code => $sub, match => qr/NULL/ );
         }
         my $tally_data = $thisfield->subfield($sub) || 'NULL';
         $tally{$tally_data}++;
         $modified_subfield++;
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
$modified_subfield subfields modified in $modified_record records.
END_REPORT

print "\nTally results:\n\n";
foreach my $kee (sort keys %tally) {
   print $kee.':  '.$tally{$kee}."\n";
}

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
