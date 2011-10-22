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
use Text::CSV;
use C4::Context;
use C4::Items;
$|=1;

my $debug= 0;

GetOptions(
    'debug'    => \$debug,
);

#if (($infile_name eq '')){
#   print "Something's missing.\n";
#   exit;
#}

my $dbh=C4::Context->dbh();
my $i=0;
my $sth;
my $sth2;
my $row;

print "Inserting hold settings:\n";
$sth = $dbh->prepare("SELECT branchcode FROM branches");
$sth2 = $dbh->prepare("INSERT INTO branch_item_rules (branchcode,itemtype,holdallowed) VALUES (?,?,?)");
$sth->execute();
while ($row = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $sth2->execute($row->{'branchcode'},"LOCALHOLD",1);
   $sth2->execute($row->{'branchcode'},"LOCALHOLD1",1);
   $sth2->execute($row->{'branchcode'},"LOCALHOLD2",1);
   $sth2->execute($row->{'branchcode'},"WALKIN",0);
   $sth2->execute($row->{'branchcode'},"WALKIN1",0);
   $sth2->execute($row->{'branchcode'},"WALKIN2",0);
}
print "\r$i rules created\n";

print "Remapping NEWAUDIO items:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itype='NEWBOOK'
                      AND (ccode='BOOKONCD' OR ccode='BOOKONMP' OR ccode='BOOKONCASS')");
$sth->execute();
while ($row = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   C4::Items::ModItem({itype=> "NEWAUDIO"},undef,$row->{'itemnumber'});
}

print "\n$i items modified.\n"; 

print "All Done!\n";

