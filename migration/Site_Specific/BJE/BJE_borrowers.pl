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
#   -modifies borrowers, if --update flag is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -counts of edits

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

print "Outputting borrower attributes:\n";
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT cardnumber,phonepro FROM borrowers WHERE categorycode='JCHSSTU' AND phonepro IS NOT NULL AND phonepro != ''");
$sth->execute();
open my $output_file,'>','/home/load19/data/borrower_attributes.csv';
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   print {$output_file} "$line->{cardnumber},CLASS:$line->{phonepro}\n";
}
close $output_file;
print "\n$i records output.\n\n";

print "Setting usernames with first letter and last name:\n";
$i=0;
$sth=$dbh->prepare("SELECT borrowernumber,surname,firstname FROM borrowers WHERE (userid IS NULL OR userid='') AND (flags IS NULL or flags=0)");
$sth->execute();
my $sth2=$dbh->prepare("SELECT borrowernumber FROM borrowers WHERE userid=?");
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $userid=substr($line->{firstname},0,1).$line->{surname};
   $userid =~ s/ //g;
   $userid = lc $userid;
   $sth2->execute($userid);
   my $record=$sth2->fetchrow_hashref();
   if (!$record->{borrowernumber}) {
      $doo_eet and ModMember(borrowernumber=>$line->{borrowernumber},userid=>$userid);
   }
}
print "\n$i records processed.\n\n";

print "Setting usernames with first two letters and last name:\n";
$i=0;
$sth=$dbh->prepare("SELECT borrowernumber,surname,firstname FROM borrowers WHERE (userid IS NULL OR userid='') AND (flags IS NULL or flags=0)");
$sth->execute();
$sth2=$dbh->prepare("SELECT borrowernumber FROM borrowers WHERE userid=?");
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $userid=substr($line->{firstname},0,2).$line->{surname};
   $userid =~ s/ //g;
   $userid = lc $userid;
   $sth2->execute($userid);
   my $record=$sth2->fetchrow_hashref();
   if (!$record->{borrowernumber}) {
      $doo_eet and ModMember(borrowernumber=>$line->{borrowernumber},userid=>$userid);
   }
}
print "\n$i records processed.\n\n";

print "Setting passwords for JCHSSTU and JCHSSTAFF:\n";
$i=0;
$sth=$dbh->prepare("SELECT borrowernumber FROM borrowers WHERE categorycode IN ('JCHSSTU','JCHSSTAFF')");
$sth->execute();
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $doo_eet and ModMember(borrowernumber=>$line->{borrowernumber},password=>'wolves');
}
print "\n$i records processed.\n\n";

print "Setting passwords for others:\n";
$i=0;
$sth=$dbh->prepare("SELECT borrowernumber FROM borrowers WHERE categorycode IN ('ADULT','CHILD','TEACHER')");
$sth->execute();
while (my $line=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $doo_eet and ModMember(borrowernumber=>$line->{borrowernumber},password=>'changeme');
}
print "\n$i records processed.\n\n";

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
