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

my %itemtypes;
my %branches;
my %locations;
my %collcodes;
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

   if ($columns[0] eq $NULL_STRING){
       $no_barcode++;
       next RECORD;
   }
   $itemtypes{$columns[3]}++;
   $branches{$columns[6]}++;
   $locations{$columns[7]}++;
   if ($columns[15]) {
      $collcodes{$columns[15]}++;
   }
}

print "\n$i records read\n";
print "\nCOUNTS OF PROBLEMS:\n";
print "NO BARCODE: $no_barcode\n\n";
print "\nRESULTS BY ITEM TYPE:\n";
foreach my $kee (sort keys %itemtypes){
   print $kee.":  ".$itemtypes{$kee}."\n";
}
print "\nRESULTS BY BRANCH:\n";
foreach my $kee (sort keys %branches){
   print $kee.":  ".$branches{$kee}."\n";
}
print "\nRESULTS BY LOCATION:\n";
foreach my $kee (sort keys %locations){
   print $kee.":  ".$locations{$kee}."\n";
}
print "\nRESULTS BY COLLECTION CODE:\n";
foreach my $kee (sort keys %collcodes){
   print $kee.":  ".$collcodes{$kee}."\n";
}
exit;
