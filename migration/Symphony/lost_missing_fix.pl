#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;

GetOptions(
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

#if (($branch eq '')){
#  print "Something's missing.\n";
#  exit;
#}

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,location FROM items WHERE location IN ('LOST','MISSING')");
$sth->execute();
my $i=0;
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($rec->{'location'} eq "LOST"){
      $debug and print "setting LOST on item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         C4::Items::ModItem({itemlost         => 1,
                             location         => undef,
                            },undef,$rec->{'itemnumber'});
      }
   }
   if ($rec->{'location'} eq "MISSING"){
      $debug and print "setting MISSING on item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         C4::Items::ModItem({itemlost         => 4,
                             location         => undef,
                            },undef,$rec->{'itemnumber'});
      }
   }
}

print "\n\n$i Records modified.\n";
