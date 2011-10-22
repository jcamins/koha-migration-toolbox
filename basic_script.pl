#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -<author>
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
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
use Readonly;
use Text::CSV_XS;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = "";

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

LINE:
while (my $line=$csv->getline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;

}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;
