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
use Data::Dumper;
use Getopt::Long;
use C4::Context;
use C4::Items;
use C4::Dates;
$|=1;

my $debug=0;
my $doo_eet=0;
my $in = "";
my $out = "";

GetOptions(
    'in=s'    => \$in,
    'out=s'   => \$out,
    'debug'   => \$debug,
    'update'  => \$doo_eet,
);

if (($in eq "") || ($out eq "")){
   print "Something's missing.\n";
   exit;
}

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber FROM items WHERE cn_source = ?");
$sth->execute($in);
my $i=0;
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   C4::Items::ModItem({cn_source        => $out},undef,$rec->{'itemnumber'}) if ($doo_eet);
}

print "\n\n$i Records modified.\n";
