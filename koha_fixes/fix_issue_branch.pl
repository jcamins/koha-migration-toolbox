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
#   -updates issues.branch to item owning library if issues.branchcode is null, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -lists items, if --debug is set
#   -number of issues considered
#   -number of issues modified

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

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

my $dbh = C4::Context->dbh();
my $issues_sth = $dbh->prepare("SELECT itemnumber FROM issues WHERE branchcode IS NULL");
my $update_sth = $dbh->prepare("UPDATE issues SET branchcode = ? WHERE itemnumber = ?");

$issues_sth->execute();
LINE:
while (my $line=$issues_sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   my $item = GetItem($line->{itemnumber},undef,undef);
   $debug and print "Item $line->{itemnumber} Branch $item->{homebranch}\n";

   if ($doo_eet) {
      $update_sth->execute($item->{homebranch},$line->{itemnumber});
   }
   $written++;
}

print << "END_REPORT";

$i issues read.
$written issues updated.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
