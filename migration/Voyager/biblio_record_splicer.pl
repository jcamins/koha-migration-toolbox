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
#   -Bib data output from SQL query, in bits and pieces
#
# DOES:
#   -nothing
#
# CREATES:
#   -MARC record file
#
# REPORTS:
#   -count of records read
#   -count of records output

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

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

my $csv=Text::CSV_XS->new({binary => 1});
my $current_record = $NULL_STRING;
my $current_recnum = 0;

open my $input_file, '<:utf8',$input_filename;
$csv->column_names($csv->getline($input_file));

open my $output_file,'>:utf8',$output_filename;

LINE:
while (my $line=$csv->getline_hr($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   if ($line->{BIB_ID} != $current_recnum) {
      if ($current_recnum) {
        print {$output_file} $current_record;
        $written++;
      }
      $current_record = $line->{RECORD_SEGMENT};
      $current_recnum = $line->{BIB_ID};
   }
   else {
      $current_record .= $line->{RECORD_SEGMENT};
   }
}
close $input_file;
close $output_file;

print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

exit;
