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
#   -nothing
#
# DOES:
#   -captures date from 008/00-05, and uses that as item accession date, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -shows what would be changed, if --debug is set
#   -count of items found
#   -count of items modified

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
use C4::Biblio;
use C4::Items;
use MARC::Record;
use MARC::Field;

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

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,biblionumber FROM items");
$sth->execute();
LINE:
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   my $biblio = GetMarcBiblio($line->{biblionumber});
   my $fld008 = $biblio->field('008');

   if (!$fld008) {
      $problem++;
      next LINE;
   }

   my $field_data = $fld008->data();
   my $year  = substr($field_data,0,2);
   my $month = substr($field_data,2,2);
   my $day   = substr($field_data,4,2);
   my @time = localtime();
   my $thisyear = $time[5]+1900;
   $thisyear = substr($thisyear,2,2);
   if ($year < $thisyear) {
      $year += 2000;
   }
   elsif ($year < 100) {
      $year += 1900;
   }
   my $date_to_set = sprintf "%4d-%02d-%02d",$year,$month,$day;
 
   $debug and print "ITEM $line->{itemnumber} Date: $date_to_set\n";
  
   if ($doo_eet) {
      ModItem({ dateaccessioned => $date_to_set },undef,$line->{itemnumber});
   }
   $written++; 
}

print << "END_REPORT";

$i records read.
$written records updated.
$problem records not updated due to problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
