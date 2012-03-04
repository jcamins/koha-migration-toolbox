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
#   -tidies up branch codes, item types, locations, collection codes, and patron categories, if --update is set.
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be done, if --debug is set
#   -counts of items added and deleted

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
use C4::Branch;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = $NULL_STRING;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $dbh = C4::Context->dbh();
my $sth;
my $sth_2;
my $sth_3;
my $insert_sth;
my $del_sth;

print "Removing unneeded branches:\n";
$i = 0;
$sth = $dbh->prepare("SELECT branchcode FROM branches 
                      WHERE branchcode NOT IN (SELECT DISTINCT homebranch FROM items)
                      AND branchcode NOT IN (SELECT DISTINCT holdingbranch FROM items)
                      AND branchcode NOT IN (SELECT DISTINCT branchcode FROM borrowers)");
$sth->execute();
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Removing branch $line->{branchcode}.\n";
   $doo_eet and DelBranch($line->{branchcode});
}
print "$i branches removed.\n";

print "Removing unneeded item types:\n";
$i = 0;
$sth = $dbh->prepare("SELECT itemtype FROM itemtypes ");
$sth_2 = $dbh->prepare("SELECT biblionumber FROM items WHERE itype =?");
$sth_3 = $dbh->prepare("SELECT biblionumber FROM biblioitems WHERE itemtype =?");
$del_sth = $dbh->prepare("DELETE FROM itemtypes WHERE itemtype=?");
$sth->execute();
ITEMTYPE:
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $sth_2->execute($line->{itemtype});
   my $line_2 = $sth_2->fetchrow_hashref();
   next ITEMTYPE if $line_2->{biblionumber};
   $sth_3->execute($line->{itemtype});
   my $line_3 = $sth_3->fetchrow_hashref();
   next ITEMTYPE if $line_3->{biblionumber};
   $debug and print "Removing item type $line->{itemtype}.\n";
   $doo_eet and $del_sth->execute($line->{itemtype});
}
print "$i item types removed.\n";

print "Removing unneeded location codes:\n";
$i = 0;
$sth = $dbh->prepare("SELECT id,authorised_value FROM authorised_values 
                      WHERE category='LOC' 
                      AND authorised_value NOT IN (SELECT DISTINCT location FROM items)");
$del_sth = $dbh->prepare("DELETE FROM authorised_values WHERE id=?");
$sth->execute();
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Removing location code $line->{authorised_value}.\n";
   $doo_eet and $del_sth->execute($line->{id});
}
print "$i location codes removed.\n";

print "Removing unneeded collection codes:\n";
$i = 0;
$sth = $dbh->prepare("SELECT id,authorised_value FROM authorised_values 
                      WHERE category='CCODE' 
                      AND authorised_value NOT IN (SELECT DISTINCT ccode FROM items)");
$del_sth = $dbh->prepare("DELETE FROM authorised_values WHERE id=?");
$sth->execute();
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Removing collection code $line->{authorised_value}.\n";
   $doo_eet and $del_sth->execute($line->{id});
}
print "$i collection codes removed.\n";

print "Removing unneeded patron category codes:\n";
$i = 0;
$sth = $dbh->prepare("SELECT categorycode FROM categories 
                      WHERE categorycode NOT IN (SELECT DISTINCT categorycode FROM borrowers)");
$del_sth = $dbh->prepare("DELETE FROM categories WHERE categorycode=?");
$sth->execute();
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Removing patron category code $line->{categorycode}.\n";
   $doo_eet and $del_sth->execute($line->{categorycode});
}
print "$i patron category codes removed.\n";

print "Inserting missing location codes:\n";
$i = 0;
$sth = $dbh->prepare("SELECT DISTINCT location FROM items
                      WHERE location IS NOT NULL
                      AND location NOT IN (SELECT authorised_value FROM authorised_values WHERE category='LOC')");
$insert_sth = $dbh->prepare("INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC',?,?)");
$sth->execute();
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Inserting location code $line->{location}.\n";
   $doo_eet and $insert_sth->execute($line->{location},$line->{location});
}
print "$i location codes added.\n";

print "Inserting missing collection codes:\n";
$i = 0;
$sth = $dbh->prepare("SELECT DISTINCT ccode FROM items
                      WHERE ccode IS NOT NULL
                      AND ccode NOT IN (SELECT authorised_value FROM authorised_values WHERE category='CCODE')");
$insert_sth = $dbh->prepare("INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE',?,?)");
$sth->execute();
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Inserting collection code $line->{ccode}.\n";
   $doo_eet and $insert_sth->execute($line->{ccode},$line->{ccode});
}
print "$i collection codes added.\n";

exit;
