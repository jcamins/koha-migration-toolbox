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
my $query = "";
my $sth;

$i=0;
$query = 'select itemnumber from items where itype="EBOOK";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itemcallnumber=>"ONLINE",cn_source=>"ddc"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items where itype="CIRC-AV" and itemcallnumber like "DVD %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"DVD"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items where itype="CIRC-AV" and itemcallnumber like "VHS %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"VHS"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items where itype="CIRC-AV" and itemcallnumber like "Audio CD %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"AUDIOCD"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items where itype="NOCIRC-PRO";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"PNCREF",location=>"TECH"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items join biblio using (biblionumber) where itype="NON-LIB" and biblio.author like "AV Media";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"AVMEDIA"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items join biblio using (biblionumber) where itype="NON-LIB" and biblio.title like "KEY %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"KEY"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items join biblio using (biblionumber) where biblio.title like "Library ECHO %";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"KEY"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items join biblio using (biblionumber) where itype="NON-LIB";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"RESERES"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber from items join biblio using (biblionumber) where itype="CIRC-RES" and location="PERMRES";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\nItem:  $row->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"PNCREF",location=>"RESERVE"},undef,$row->{'itemnumber'});
   }
}
print "\n\n$i items found and modified.\n";

