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

my %values;
my %users;
Readonly my $FIELD_SEP    => chr(254);
Readonly my $TAG_SEP      => chr(253);
Readonly my $SUB_SEP      => chr(252);
open my $input_file,'<',$input_filename;
LINE:
while (my $line=readline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s///g;
   my @columns = split /$FIELD_SEP/,$line;
   my @tags = split /$TAG_SEP/,$columns[14];
   for my $j (0..scalar(@tags)-1) {
      my @subtags = split /$SUB_SEP/,$tags[$j];
      for my $k (0..scalar(@subtags)-1) {
         my $subtag = $subtags[$k];
         $values{$subtag}++;
         $users{$subtag} = $columns[0];
      }
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
END_REPORT

foreach my $kee (sort keys %values) {
   print "$kee:   $values{$kee}  ($users{$kee})\n";
}

exit;
