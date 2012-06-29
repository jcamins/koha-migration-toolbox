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
#   -ITEMS extract from Voyager
#
# DOES:
#   -nothing
#
# CREATES:
#   -Item ID -> Barcode map
#
# REPORTS:
#   -count of records read
#   -count of records written

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

open my $input_file,'<:utf8',$input_filename;
my $csv=Text::CSV_XS->new({ binary => 1 });
$csv->column_names($csv->getline($input_file));
open my $output_file,'>:utf8',$output_filename;

LINE:
while (my $line=$csv->getline_hr($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   print {$output_file} "$line->{ITEM_ID},$line->{BARCODE}\n";
}
close $input_file;
close $output_file;


print << "END_REPORT";

$i records read and written.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
