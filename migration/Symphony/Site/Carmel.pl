#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Getopt::Long;
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $branch="";
GetOptions(
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

my $dbh=C4::Context->dbh();
my $query = 'select itemnumber from items where itype="MAGAZINE" and location="NONFICTION"';
my $sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print "." unless ($i % 25);
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"MAGAZINE",ccode=>"ADULT SERIALS"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$dbh=C4::Context->dbh();
$query = 'select itemnumber from items where itype="MAGAZINE" and location="JNONFIC"';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print "." unless ($i % 25);
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"JMAG",ccode=>"JUVENILE SERIALS"},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$dbh=C4::Context->dbh();
$query = 'select itemnumber from items where itype="ARCHIVES" and homebranch="PBYS"';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print "." unless ($i % 25);
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({homebranch=>"PBLH",
                          holdingbranch=>"PBLH"},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

