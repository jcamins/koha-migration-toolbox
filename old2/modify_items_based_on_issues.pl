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

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,issuedate,date_due FROM issues");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   my $sth2=$dbh->prepare("SELECT biblionumber,issues FROM items WHERE itemnumber=$rec->{'itemnumber'}");
   $sth2->execute();
   my $itmrec=$sth2->fetchrow_hashref();
   $itmrec->{'issues'}++;
   C4::Items::ModItem({issues           => $itmrec->{'issues'},
                       itemlost         => 0,
                       datelastborrowed => $rec->{'issuedate'},
                       datelastseen     => $rec->{'issuedate'},
                       onloan           => $rec->{'date_due'}
                      },$itmrec->{'biblionumber'},$rec->{'itemnumber'});
}
