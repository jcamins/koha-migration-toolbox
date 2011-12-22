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
#   -nothing
#
# DOES:
#   -corrects borrower zipcodes that start with zero, if --update is given
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is given
#   -count of records examined
#   -count of record modified

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

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $modified = 0;
my $problem = 0;

my $input_filename = "";

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

#for my $var ($input_filename) {
#   croak ("You're missing something") if $var eq $NULL_STRING;
#}

use C4::Context;
use C4::Members;
my $dbh   = C4::Context->dbh();
my $query = "SELECT borrowernumber,zipcode FROM borrowers where zipcode is not null and zipcode != ''";
my $find  = $dbh->prepare($query);
$find->execute();

LINE:
while (my $line=$find->fetchrow_hashref()) {
   last LINE if ($debug && $doo_eet && $modified >0);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   next LINE if ($line->{zipcode} !~ m/^\d+$/);
   next LINE if (length($line->{zipcode}) >= 5);

   my $newzip = sprintf "%05d",$line->{zipcode};

   $debug and print "Borrower: $line->{borrowernumber}   Changing $line->{zipcode} to $newzip.\n";
   if ($doo_eet){
      C4::Members::ModMember(borrowernumber => $line->{'borrowernumber'},
                             zipcode        => $newzip,
                            );
   }
   $modified++;
}

print << "END_REPORT";

$i records found.
$modified records updated.
END_REPORT

exit;

