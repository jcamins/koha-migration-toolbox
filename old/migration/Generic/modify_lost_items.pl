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
my $sth=$dbh->prepare("select biblionumber,items.itemnumber AS itmnum from items left join accountlines on (items.itemnumber=accountlines.itemnumber) where accountlines.accounttype='L'");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   C4::Items::ModItem({ itemlost         => 1
                      },$rec->{'biblionumber'},$rec->{'itmnum'});
}
