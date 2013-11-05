#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
# Script is slow.  Fixes ~14,000 patrons per hour (jn)
#  
use strict;
use warnings;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Members;
$|=1;
my $debug=0;
my $doo_eet=0;

GetOptions(
    'update'     => \$doo_eet,
    'debug'      => \$debug,
);

my $dbh=C4::Context->dbh();
my $i=0;
my $modified=0;
my $query = "SELECT borrowernumber,city FROM borrowers where state = '' or state is null";

my $find = $dbh->prepare($query);
$find->execute();
while (my $row=$find->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $row->{city} =~ s/\s+$//;
   my ($city,$state) = split(/[, ]([^, ]+)$/,$row->{'city'},2);
   if ($city && $city ne $row->{'city'}){
      $state =~ s/^\s+//;
      $city =~ s/,$//;
      $debug and print "Changing $row->{'borrowernumber'} $row->{'city'}   NEW CITY:$city  NEW ST:$state \n";
      $doo_eet and C4::Members::ModMember(borrowernumber => $row->{'borrowernumber'}, 
                                          city           => $city,
                                          state          => $state);
      $modified++;
   }
}

print "\n$i records examined.\n$modified records modified.\n";
