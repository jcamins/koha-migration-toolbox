#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
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
use C4::Context;
use C4::Items;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,paidfor FROM items WHERE paidfor IS NOT NULL");
$sth->execute();
ITEM:
while (my $this_item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $new_value = $this_item->{paidfor};
   if ($new_value =~ m/^\d+\/\d+\/\d+$/) {
      $new_value = $NULL_STRING;
   }
   $new_value =~ s/Entry date: \d+\/\d+\/\d+//gi;
   $new_value =~ s/Entry date: \d+//gi;
   $new_value =~ s/ \/ $//g;
   next ITEM if $new_value eq $this_item->{paidfor};
   $debug and print "Item: $this_item->{itemnumber} Old: $this_item->{paidfor}  New: $new_value\n";
   if ($doo_eet) {
      ModItem({ paidfor => $new_value },undef,$this_item->{itemnumber});
   }
   $written++;
}

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
