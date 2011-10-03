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
my $query;
my $sth;

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and location="CIRCOFF" and itemnotes like "CD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   #$newnotes =~ s/^CD[- ]ROM//gi;
   #$newnotes =~ s/^CD//gi;
   #$newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"CIRCOFFCD", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and location="CIRCOFF" and itemnotes like "DVD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^DVD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"CIRCOFFDVD", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and location="CIRCOFF";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "Item:  $row->{'itemnumber'} \n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"CIRCOFFBK"},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and location="CD" and itemnotes like "CD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^CD[- ]ROM//gi;
   $newnotes =~ s/^CD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"NONCIRCCD", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and location="CD" and itemnotes like "DVD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^DVD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"NONCIRCDVD", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and itemnotes like "CD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^CD[- ]ROM//gi;
   $newnotes =~ s/^CD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"CDROM", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and itemnotes like "DVD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^DVD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"DVD", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and itemnotes like "AUDIO CD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^AUDIO CD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"AUDIOCD", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPRES" and itemnotes like "CD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^CD[- ]ROM//gi;
   $newnotes =~ s/^CD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"RESCDROM", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPRES" and itemnotes like "DVD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^DVD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"RESDVD", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPRES" and itemnotes like "AUDIO CD%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $newnotes = $row->{'itemnotes'};
   $newnotes =~ s/^AUDIO CD//gi;
   $newnotes =~ s/^[- ]+//;
   $debug and print "Item:  $row->{'itemnumber'} OLD: $row->{itemnotes} NEW: $newnotes\n";
   if ($doo_eet){
      C4::Items::ModItem({itype=>"RESAUDIOCD", itemnotes=>$newnotes},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and itemcallnumber like "AUDIO%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($doo_eet){
      C4::Items::ModItem({itype=>"AUDIOTAPE"},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and itemcallnumber like "VIDIO%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($doo_eet){
      C4::Items::ModItem({itype=>"VIDIOTAPE"},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and itemcallnumber like "VHS%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($doo_eet){
      C4::Items::ModItem({itype=>"VIDIOTAPE"},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and itemcallnumber like "SLIDES%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($doo_eet){
      C4::Items::ModItem({itype=>"SLIDE"},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";

$i=0;
$query = 'select itemnumber,itemnotes from items where itype="TEMPMEDIA" and itemcallnumber like "MODEL%";';
$sth=$dbh->prepare($query);
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($doo_eet){
      C4::Items::ModItem({itype=>"MODEL"},undef,$row->{'itemnumber'});
   }
}

print "\n\n$i items found and modified.\n";
