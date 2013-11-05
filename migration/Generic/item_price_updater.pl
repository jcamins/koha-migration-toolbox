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
#   -amount to be added to item prices
#
# DOES:
#   -updates the value, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of items modified
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

my $new_value       = q{};

GetOptions(
   'val:s'    => \$new_value,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if ($new_value eq q{}){
   print "Something's missing.\n";
   exit;
}

my $written=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,price FROM items");
$sth->execute();
RECORD:
while (my $row=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $i>0);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);

   next RECORD if (!$row->{price});

   my $newprice = $row->{price} + $new_value;

   $debug and print "($row->{itemnumber})  price => $row->{price}   adding $new_value to $newprice for replprice\n";

   if ($doo_eet){
      C4::Items::ModItem({ replacementprice => $newprice },undef,$row->{'itemnumber'});
   }
   $written++;
}

print "\n\n$i records read.\n$written items updated.\n";
