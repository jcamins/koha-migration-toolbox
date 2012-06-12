#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -WHERE clause for select
#
# DOES:
#   -deletes the items, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of items found
#   -count of items deleted
#   -details of what will be changed, if --debug is set

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Items;
$|=1;
my $debug = 0;
my $doo_eet = 0;
my $i=0;

my $where_clause    = q{};

GetOptions(
   'where:s'  => \$where_clause,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if ($where_clause eq q{}){
   print "Something's missing.\n";
   exit;
}

my $written=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT biblionumber,itemnumber FROM items WHERE $where_clause");
$sth->execute();
RECORD:
while (my $row=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $i>0);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);

   $debug and print "Biblio: $row->{biblionumber}  Item: $row->{itemnumber} \n";

   if ($doo_eet){
      C4::Items::DelItem($dbh,$row->{biblionumber},$row->{itemnumber});
   }
   $written++;
}

print "\n\n$i records read.\n$written items deleted.\n";
