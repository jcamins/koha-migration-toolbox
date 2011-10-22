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
#   -updates the database, if --update is specified:
#     * adds new authorised_value and item type
#     * edits items
#     * deletes old authorised_value
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -Itemnumbers that would be edited, if --debug is specified
#   -Counts of items edited

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

if ($doo_eet){
   $dbh->do("insert into authorised_values (category,authorised_value,lib) VALUES ('LOC','Offsite C','Offsite Storage C');");
   $dbh->do("insert into itemtypes (itemtype,description,notforloan) VALUES ('VFILE','Vertical File',1);");
}

print "Modifying location 'offsite' items to 'Offsite C'\n";
my $query = 'select itemnumber from items where location="offiste"';
my $sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"Offsite C"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
print "Modifying Vertical File items to new VFILE type\n";
$query = 'select itemnumber from items where itype="ARCH" and itemcallnumber like "artist files%"';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"VFILE"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

if ($doo_eet){
   $dbh->do("delete from authorised_values WHERE category='LOC' and authorised_value='offsite';");
}

