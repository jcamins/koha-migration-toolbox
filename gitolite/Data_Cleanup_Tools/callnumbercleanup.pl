#!/usr/bin/perl

# This script removes |'s from the itemcallnumber field
# It takes the first listed call number as preferred, if it exists

use C4::Context;

my $usecount = 0;

my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare(  "SELECT itemnumber, biblionumber, itemcallnumber FROM items WHERE itemcallnumber LIKE '% | %'");
$sth->execute();

while (@row = $sth->fetchrow_array()){
  my $itemnumber = $row[0];
  my $biblionumber = $row[1];
  my $callnumbers = $row[2];
  my @callnumbersarray = split(/ +\| /, $callnumbers);
  my $callnumber = $callnumbersarray[0];
#was item level call number empty?
    $callnumber = $callnumbersarray[1] unless $callnumber;

  #ModItem({itemcallnumber => $callnumber},$biblionumber,$itemnumber);
  print "$itemnumber replaces \"$callnumbers\" with \"$callnumber\"\n";
  #print "$itemnumber: @callnumbersarray\n";
  $usecount++;
}

print "Total of $usecount records modified\n";