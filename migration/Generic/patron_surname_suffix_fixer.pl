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
#   -moves suffixes into suffix field, and puts last names alone in the surname field, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is set
#   -counts of records considered
#   -counts of records modified

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

my @suffixes = qw/Sr Jr III IV/;
my $dbh        = C4::Context->dbh();
my $sth        = $dbh->prepare("SELECT borrowernumber, firstname, surname, suffix FROM borrowers WHERE suffix IS NULL");
my $update_sth = $dbh->prepare("UPDATE borrowers SET firstname = ?, surname = ?, suffix = ? WHERE borrowernumber = ?");
$sth->execute();
BORROWER:
while (my $borrower=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   my $firstname = $borrower->{firstname};
   my $lastname = $borrower->{surname};
   $lastname =~ s/\.$//;

SUFFIX:
   foreach my $suffix (@suffixes) {
      if ($lastname !~ m/$suffix/i) {
         next SUFFIX;
      }
      $debug and print "Found borrower: $firstname $lastname\n";
   }
}

print << "END_REPORT";

$i records considered.
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
