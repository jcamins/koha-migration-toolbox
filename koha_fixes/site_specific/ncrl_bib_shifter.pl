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

my $map_filename = $NULL_STRING;
my @biblio;

GetOptions(
    'map=s'    => \$map_filename,
    'bib=s'    => \@biblio,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

croak ("You're missing something") if scalar(@biblio) == 0;

my %bib_map;
if ($map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$map_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $bib_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT itemnumber,homebranch FROM items WHERE biblionumber = ?");

BIBLIO:
foreach my $biblionumber (@biblio) {
   $sth->execute($biblionumber);
ITEM:
   while (my $item=$sth->fetchrow_hashref()) {
      $i++;
      print '.'    unless ($i % 10);
      print "\r$i" unless ($i % 100);
      if (!exists $bib_map{$item->{homebranch}}) {
         print "$item->{homebranch} not in map!\n";
         $problem++;
         next ITEM;
      }
      $debug and print "Item $item->{itemnumber} ($item->{homebranch}) from $biblionumber to $bib_map{$item->{homebranch}}\n";
      if ($doo_eet) {
         my $return = MoveItemFromBiblio($item->{itemnumber},$biblionumber,$bib_map{$item->{homebranch}});
         if (!$return) {
            $problem++;
            next ITEM; 
         }
      }
      $written++;
   }
}

print << "END_REPORT";

$i items found.
$written items modified.
$problem items not modified due to problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
