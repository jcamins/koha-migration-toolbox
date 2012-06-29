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
#   -CSV of item ID and stat codes
#   -map of stat codes to collection codes, with priority
#   -map of item ID to barcode
#
# DOES:
#   -sets item collection codes, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be modified, if --debug is set
#   -counts of items touched

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use C4::Context;
use C4::Items;

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

my $input_filename = $NULL_STRING;
my $item_id_map_filename = $NULL_STRING;
my $code_map_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'item_map=s' => \$item_id_map_filename,
    'code_map=s' => \$code_map_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename,$item_id_map_filename,$code_map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

print "reading item map...\n";
my %item_id_map;
if ($item_id_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$item_id_map_filename;
   while (my $line = $csv->getline($map_file)) {
      my @data= @$line;
      $item_id_map{$data[0]} = $data[1];
   }
   close $map_file;
}

print "reading code map...\n";
my %code_map;
my %code_priority;
if ($code_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$code_map_filename;
   while (my $line = $csv->getline($map_file)) {
      my @data= @$line;
      $code_map{$data[0]} = $data[1];
      $code_priority{$data[0]} = $data[2];
   }
   close $map_file;
}

my %item_code_priority;
my $skip = 0;
my $csv = Text::CSV_XS->new( {binary => 1} );
open my $input_file,'<',$input_filename;
RECORD:
while (my $line=$csv->getline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;
   my $item = GetItemnumberFromBarcode($item_id_map{$data[0]});
   if (!$item) {
      $problem++;
      next RECORD;
   }
   if (!defined $item_code_priority{$item}) {
      $item_code_priority{$item} = 999;
   }
   if ($item_code_priority{$item} < $code_priority{$data[1]}) {
      $skip++;
      next RECORD;
   }
   $item_code_priority{$item} = $code_priority{$data[1]};
   if ($doo_eet) {
      ModItem({ ccode => $code_map{$data[1]} }, undef, $item);
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records modified.
$skip records skipped due to higher-priority values already set. 
$problem records not loaded due to problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
