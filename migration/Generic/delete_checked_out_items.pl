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
#   -cardnumber
#
# DOES:
#   -discharges and deletes items checked out to that cardnumber
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of items deleted

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

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $barcode = 0;

GetOptions(
    'card:s'   => \$barcode,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($barcode) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $dbh=C4::Context->dbh;
my $sth=$dbh->prepare("SELECT itemnumber,biblionumber FROM issues 
                              JOIN borrowers USING (borrowernumber)
                              JOIN items USING (itemnumber)
                              WHERE cardnumber='$barcode'");
my $del_sth=$dbh->prepare("DELETE FROM issues WHERE itemnumber=?");
$sth->execute();
LINE:
while (my $rec=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Item $rec->{itemnumber}\n";
   if ($doo_eet) {
      $del_sth->execute($rec->{itemnumber});
      DelItem($dbh,$rec->{biblionumber},$rec->{itemnumber});
   }
   $written++;
}

print << "END_REPORT";

$i items found.
$written items dropped.
END_REPORT

exit;
