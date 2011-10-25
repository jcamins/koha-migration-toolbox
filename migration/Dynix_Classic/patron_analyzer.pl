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
my $j       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = "";

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %cities;
my %cityzip;
my %branches;
my %categories;
my $no_barcode = 0;
Readonly my $field_sep => chr(254);

open my $input_file,'<',$input_filename;
RECORD:
while ( my $line = readline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   
   chomp $line;
   $line =~ s/$//;
   my @columns = split /$field_sep/,$line;

   if ($columns[0] eq $NULL_STRING) {
       $no_barcode++;
       next RECORD;
   }
   if (length($columns[3]) == 2) {
      my $citystr = $columns[3].'-'.substr($columns[4],0,5);
      $cityzip{$citystr}++;
      $cities{$columns[3]}++;
   }
   $branches{$columns[15]}++;
   $categories{$columns[9]}++;
}

print "\n$i records read\n";
print "\nCOUNTS OF PROBLEMS:\n";
print "NO BARCODE: $no_barcode\n\n";
print "\nRESULTS BY CITY:\n";
foreach my $kee (sort keys %cities){
   print $kee.":  ".$cities{$kee}."\n";
}
print "\nRESULTS BY CITY AND ZIP:\n";
foreach my $kee (sort keys %cityzip){
   print $kee.":  ".$cityzip{$kee}."\n";
}
print "\nRESULTS BY BRANCH:\n";
foreach my $kee (sort keys %branches){
   print $kee.":  ".$branches{$kee}."\n";
}
print "\nRESULTS BY CATEGORYCODE:\n";
foreach my $kee (sort keys %categories){
   print $kee.":  ".$categories{$kee}."\n";
}
exit;
