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

my $input_filename        = $NULL_STRING;
my $biblio_map_filename   = $NULL_STRING;
my %biblio_map;

GetOptions(
    'in=s'      => \$input_filename,
    'bib_map=s' => \$biblio_map_filename,
    'debug'     => \$debug,
    'update'    => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if ($biblio_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$biblio_map_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $biblio_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my %itype_map=( 0  => 'STANDARD',
                30 => '3DAY',
              );

my %lostval_map=( 'z' => 5,
                  'l' => 1,
                  'm' => 4,
                  's' => 1,
                  'n' => 2,
                  '$' => 3,
                  '0' => 1,
                );

my $csv = Text::CSV_XS->new();
open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file));
ITEM:
while (my $line=$csv->getline_hr($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $itemnumber = GetItemnumberFromBarcode($line->{BARCODE});
   next ITEM if $itemnumber;
   my ($oclc_number,undef) = split (/;/,$line->{'OCLC #'});
   my $biblionumber = $biblio_map{$oclc_number} || $NULL_STRING;
   if ($biblionumber eq $NULL_STRING) {
      print "\nPROBLEM BIBLIO $oclc_number BARCODE $line->{BARCODE}\n";
      $problem++;
      next ITEM;
   }
   my %item;
   $item{barcode}       = $line->{BARCODE};
   $item{homebranch}    = 'ROSLIN';
   $item{holdingbranch} = 'ROSLIN';
   $item{itype}         = $itype_map{$line->{'I TYPE'}};
   $item{location}      = uc $line->{'ITEM LOC'};
   $item{itemlost}      = $lostval_map{$line->{STATUS}} || 1;
   $debug and print Dumper(%item);
   $doo_eet and AddItem(\%item,$biblionumber);
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
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
