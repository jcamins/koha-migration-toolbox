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
use C4::Context;
use C4::Items;
use C4::Dates;
$|=1;

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,issuedate,date_due FROM issues where itemnumber >919000");
$sth->execute();
my $i=0;
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $sth2=$dbh->prepare("SELECT biblionumber,issues FROM items WHERE itemnumber=$rec->{'itemnumber'}");
   $sth2->execute();
   my $itmrec=$sth2->fetchrow_hashref();
   C4::Items::ModItem({itemlost         => 0,
                       datelastborrowed => $rec->{'issuedate'},
                       datelastseen     => $rec->{'issuedate'},
                       onloan           => $rec->{'date_due'}
                      },$itmrec->{'biblionumber'},$rec->{'itemnumber'});
}

print "\n\n$i Records modified.\n";

