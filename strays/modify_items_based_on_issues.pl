#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# If you use the General Purpose Database Table Loader for issues, this
# script will modify the items appropriately.
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
my $i=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,issuedate,date_due FROM issues join items using (itemnumber)
                       where onloan is null");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   C4::Items::ModItem({itemlost         => 0,
                       datelastborrowed => $rec->{'issuedate'},
                       datelastseen     => $rec->{'issuedate'},
                       onloan           => $rec->{'date_due'}
                      },undef,$rec->{'itemnumber'});
}
print "\n\n$i items edited.";

