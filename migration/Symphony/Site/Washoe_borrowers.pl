#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -updates borrowers to Washoe specs, if --update is specified
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is specified
#   -count of borrowers modified

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
use C4::Members;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;


GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

#for my $var ($input_filename) {
#   croak ("You're missing something") if $var eq $NULL_STRING;
#}

my $dbh                  = C4::Context->dbh();
my $sth;
my $attribute_insert_sth = $dbh->prepare("INSERT INTO borrower_attributes
                                          (borrowernumber,code,attribute)
                                          VALUES (?,'COLL',1)");

$i       = 0;
$sth     = $dbh->prepare("SELECT borrowernumber FROM borrowers 
                          WHERE dateofbirth > date_sub(now(),interval 18 year) AND categorycode='BLOCKED'");
$sth->execute();
while (my $borrower = $sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Adding debar, categorycode JUV for $borrower->{borrowernumber}.\n";
   if ($doo_eet) {
      ModMember(borrowernumber => $borrower->{borrowernumber},
                categorycode   => 'JUV',
                debarred       => '2099-12-31',
               );
   }
}

print "\n\n"; 
print "$i records read and modified.\n";

$i       = 0;
$sth     = $dbh->prepare("SELECT borrowernumber FROM borrowers 
                          WHERE dateofbirth < date_sub(now(),interval 18 year) AND categorycode='BLOCKED'");
$sth->execute();
while (my $borrower = $sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Adding debar, categorycode ADULT for $borrower->{borrowernumber}.\n";
   if ($doo_eet) {
      ModMember(borrowernumber => $borrower->{borrowernumber},
                categorycode   => 'ADULT',
                debarred       => '2099-12-31',
               );
   }
}
 
print "\n\n"; 
print "$i records read and modified.\n";

$i       = 0;
$sth     = $dbh->prepare("SELECT borrowernumber FROM borrowers 
                          WHERE dateofbirth > date_sub(now(),interval 18 year) AND categorycode='COLLECTION'");
$sth->execute();
while (my $borrower = $sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Adding debar, COLL tag, categorycode JUV for $borrower->{borrowernumber}.\n";
   if ($doo_eet) {
      ModMember(borrowernumber => $borrower->{borrowernumber},
                categorycode   => 'JUV',
                debarred       => '2099-12-31',
               );
      $attribute_insert_sth->execute($borrower->{borrowernumber});
   }
}
 
print "\n\n"; 
print "$i records read and modified.\n";

$i       = 0;
$sth     = $dbh->prepare("SELECT borrowernumber FROM borrowers 
                          WHERE dateofbirth < date_sub(now(),interval 18 year) AND categorycode='COLLECTION'");
$sth->execute();
while (my $borrower = $sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Adding debar, COLL tag, categorycode ADULT for $borrower->{borrowernumber}.\n";
   if ($doo_eet) {
      ModMember(borrowernumber => $borrower->{borrowernumber},
                categorycode   => 'ADULT',
                debarred       => '2099-12-31',
               );
      $attribute_insert_sth->execute($borrower->{borrowernumber});
   }
}
 
print "\n\n"; 
print "$i records read and modified.\n";

$i       = 0;
$sth     = $dbh->prepare("SELECT borrowernumber FROM borrowers 
                          WHERE dateofbirth > date_sub(now(),interval 18 year) AND categorycode='NNA'");
$sth->execute();
while (my $borrower = $sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Adding gonenoaddress, categorycode JUV for $borrower->{borrowernumber}.\n";
   if ($doo_eet) {
      ModMember(borrowernumber => $borrower->{borrowernumber},
                categorycode   => 'JUV',
                gonenoaddress  => 1,
               );
   }
}
 
print "\n\n"; 
print "$i records read and modified.\n";

$i       = 0;
$sth     = $dbh->prepare("SELECT borrowernumber FROM borrowers 
                          WHERE dateofbirth < date_sub(now(),interval 18 year) AND categorycode='NNA'");
$sth->execute();
while (my $borrower = $sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Adding gonenoaddress, categorycode ADULT for $borrower->{borrowernumber}.\n";
   if ($doo_eet) {
      ModMember(borrowernumber => $borrower->{borrowernumber},
                categorycode   => 'ADULT',
                gonenoaddress  => 1,
               );
   }
}
 
print "\n\n"; 
print "$i records read and modified.\n";

exit;
