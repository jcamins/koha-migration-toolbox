#!/usr/bin/perl

# This script standardizes volume declarations in enumchron
# 'v.' and 'v.  ' are replaced with 'v. ' (spacing commonly set to 1)

use C4::Context;
use C4::Items;

my $usecount = 0;

my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare(  "SELECT itemnumber, biblionumber, enumchron FROM items 
                           WHERE enumchron LIKE '%v.  %' OR 
                           enumchron LIKE '%v.%' AND enumchron NOT like '%v. %'");
$sth->execute();

while (@row = $sth->fetchrow_array()){
  my $itemnumber = $row[0];
  my $biblionumber = $row[1];
  my $enumchron1 = $row[2];
  my $enumchron2 = $enumchron1;
  $enumchron2 =~ s/v\.\s*(\d.*)/v. $1/i;
  ModItem({enumchron => $enumchron2},$biblionumber,$itemnumber);
  #print "$itemnumber replaces \"$enumchron1\" with \"$enumchron2\"\n";
  $usecount++;
  print "\rCurrent progress: $usecount";
}

print "\nTotal of $usecount records modified\n";
