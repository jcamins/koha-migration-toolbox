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

my $written;
my $dbh=C4::Context->dbh();
my $query;
my $sth;

$i=0;
$written=0;
$query = 'select itemnumber from items where location="ADULTTMP" and itemcallnumber like "F %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"ADULTFIC"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$written=0;
$query = 'select itemnumber from items where location="ADULTTMP" and itemcallnumber like "MAG %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"PERIDOCALS"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$written=0;
$query = 'select itemnumber from items where location="ADULTTMP";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"ANF"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$written=0;
$query = 'select itemnumber from items where location="CHILDTMP" and itemcallnumber like "STS %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"STORYTIME"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$written=0;
$query = 'select itemnumber from items where location="CHILDTMP";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"CHILDREN"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$written=0;
$query = 'select itemnumber from items where location="STAFFTMP" and itemcallnumber like "PROF %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"OFFICEDIR"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$written=0;
$query = 'select itemnumber from items where location="STAFFTMP" and itemcallnumber like "Y PROF %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"OFFICETEEN"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$written=0;
$query = 'select itemnumber from items where location="STAFFTMP" and itemcallnumber like "CR %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location=>"YOUTHDESK"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$written=0;
$query = 'select itemnumber,itemcallnumber from items where ccode="DVD" and itemcallnumber like "DVD %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newcall=$row->{'itemcallnumber'};
   $newcall =~ s/^DVD //;
   $debug and print "\nItem:  $row->{'itemnumber'}   $newcall\n";
   if ($doo_eet){
      C4::Items::ModItem({itemcallnumber=>$newcall},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";
