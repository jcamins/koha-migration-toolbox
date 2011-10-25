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
#   -bizarre Dynix delimited file
#
# DOES:
#   -nothing
#
# CREATES:
#   -a file that is parseable as delimited by OpenOffice
#
# REPORTS:
#   -count of lines read and processed

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

Readonly my $FIELD_SEP => chr(254);

open my $input_file,  '<', $input_filename;
open my $output_file, '>', $output_filename;
LINE:
while (my $line=readline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s///g;
   $line =~ s/$FIELD_SEP/\|/g;
   print {$output_file} $line."\n";
   $written++;
}
close $input_file;
close $output_file;

print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

exit;
