#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -file of CSV-delimited data
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of values in designated columns
#

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
my $csv_delim            = 'comma';
my $skip_header     = 0;
my @columns;

GetOptions(
    'in=s'         => \$input_filename,
    'delimiter=s'  => \$csv_delim,
    'skip_header'  => \$skip_header,
    'column=s'     => \@columns,
    'debug'        => \$debug,
);

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                  'space' => ' ',
                );

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $delimiter{$csv_delim} });
my %data_matrix;

open my $input_file,'<',$input_filename;
if ($skip_header) {
   my $dummy = $csv->getline($input_file);
}

RECORD:
while (my $line = $csv->getline($input_file)) {
   last RECORD if ($debug && $i>5);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data=@$line;
   $debug and print Dumper(@data);

   foreach my $column (@columns) {
      $data_matrix{$column}{$data[$column]}++;
   }
}
close $input_file;
print << "END_REPORT";

$i records read.
END_REPORT

foreach my $column (@columns) {
print "\nData for column $column:\n";
   foreach my $kee (sort keys %{ $data_matrix{$column} }) {
      print $kee.':  '.$data_matrix{$column}{$kee}."\n";
   }
}
print "\n";
exit;
