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
#   -a CSV file
#   -which columns to make into another CSV
#
# DOES:
#   -nothing
#
# CREATES:
#   -a new reordered CSV
#
# REPORTS:
#   -counts of records read and written

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
my $csv_delim       = 'comma';
my $skip_header     = 0;
my @columns_to_use;

GetOptions(
    'in=s'        => \$input_filename,
    'out=s'       => \$output_filename,
    'delimiter=s' => \$csv_delim,
    'skip_header' => \$skip_header,
    'col=s'       => \@columns_to_use,
    'debug'       => \$debug,
    'update'      => \$doo_eet,
);

for my $var ($input_filename,$output_filename,$csv_delim) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if (scalar @columns_to_use == 0){
   croak ("You didn't specify any output columns.");
}

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                );

my $csv=Text::CSV_XS->new({ binary=>1, sep_char => $delimiter{$csv_delim} });
open my $input_file,'<',$input_filename;
open my $output_file,'>',$output_filename;
if ($skip_header) {
   my $dum=$csv->getline($input_file);
}
LINE:
while (my $line=$csv->getline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;
   my $output_string = $NULL_STRING;
   foreach my $column (@columns_to_use) {
      if ($data[$column] =~ /,/) {
         $output_string .= '"'.$data[$column].'"';
      }
      else {
         $output_string .= $data[$column];
      }
      $output_string .= ',';
   }
   $output_string =~ s/\,$//;
   print {$output_file} "$output_string\n";
   $written++;
}
close $output_file;
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
