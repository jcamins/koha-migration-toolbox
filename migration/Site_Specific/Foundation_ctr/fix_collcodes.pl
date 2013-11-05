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
   my $fld = $biblio->subfield('910','a');

   if (!$fld) {
      next LINE;
   }

   my $coll_code = $fld =~ /professional/i ? 'PROF'
                   : $fld =~ /serial/i     ? 'SER'
                   : $NULL_STRING;

   if ($coll_code eq $NULL_STRING) {
      next LINE;
   }

   $debug and print "ITEM $line->{itemnumber} Field: $fld CCODE: $coll_code\n";
  
   if ($doo_eet) {
      ModItem({ ccode => $coll_code },undef,$line->{itemnumber});
   }
   $written++; 
}

print << "END_REPORT";

$i records read.
$written records updated.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
