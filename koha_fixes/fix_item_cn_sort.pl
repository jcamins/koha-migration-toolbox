#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -Joy Nelson
# 
# Modification log: (initial and date)
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -updates items.cn_sort, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
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
my $items_sth = $dbh->prepare("SELECT itemnumber, itemcallnumber, cn_source FROM items");
my $itemupdate_sth = $dbh->prepare("UPDATE items SET cn_sort = ? WHERE itemnumber = ?");

$items_sth->execute();
my $newsort;
my $call_num;
my $source;
my $itemnum;

LINE:
while (my $line=$items_sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   $call_num = $line->{'itemcallnumber'};
   $source = $line->{'cn_source'};
   $itemnum = $line->{'itemnumber'};
   $newsort= C4::ClassSource::GetClassSort($source, $call_num, "");

$debug and print "$itemnum    $call_num   $newsort\n";


   if ($doo_eet) {
   $itemupdate_sth->execute($newsort,$itemnum);
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
