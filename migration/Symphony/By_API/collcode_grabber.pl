#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -input items.dat file extract from Symphony
#   -optional map to translate collection codes
#   -whether or not to swap category 1 and 2
#
# DOES:
#   -nothing
#
# CREATES:
#   -CSV file in the following form:
#      <item barcode>,<new collection code>
#
# REPORTS:
#   -count of records read
#   -count of records written
#   -table of counts by collection code

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $infile_name = "";
my $outfile_name = "";
my $collcode_map_name = "";
my %collcode_map;
my $reverse_cats = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'collcode_map=s'    => \$collcode_map_name,
    'reverse_cats'  => \$reverse_cats,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

if ($collcode_map_name){
   my $csv = Text::CSV_XS->new();
   open my $mapfile,"<$collcode_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $collcode_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

open my $infl,"<",$infile_name;
open my $outfl,">",$outfile_name;
my $written=0;
my %collcodecount;

RECORD:
while (my $line=readline($infl)) {
   #last if ($debug and $j > 2);
   $i++;
   print "." unless $i % 10;;
   print "\r$i" unless $i % 100;
 
   my (undef,$barcode,$rest)= split(/\|/,$line,3);
   $barcode =~ s/ //g;
   my ($cat1,$cat2);
   (undef,undef,$cat1,$cat2,undef) = split(/\|/,$rest);

   if ($reverse_cats){
      ($cat1,$cat2) = ($cat2,$cat1);
   }
   my $part1 = $cat1 ? substr($cat1,0,2) : "__";
   my $part2 = $cat2 ? substr($cat2,0,8) : "________";
   my $finalcode = $part1.$part2;

   my $collcode = "";
   $collcode = $finalcode if ($finalcode ne "__________");
   if (exists($collcode_map{$collcode})){
      $collcode = $collcode_map{$collcode};
   }

   if ($collcode ne q{}){
      print {$outfl} "$barcode,$collcode\n";
      $collcodecount{$collcode}++;
      next RECORD;
   }
}

print "\n\n$i items read.\n$written items written.\n";
print "\nCOLLECTION CODES\n";
foreach my $kee (sort keys %collcodecount){
   print $kee.":   ".$collcodecount{$kee}."\n";
}
print "\n";
close $outfl;
close $infl;
