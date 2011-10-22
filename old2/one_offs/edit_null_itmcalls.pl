#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# For all items, if no call number exists, this script will copy the 090, if 090 
# exists.
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use C4::Context;
use C4::Items;
use MARC::Record;

my $skipped=0;
my $edited=0;
my $blocked=0;
my $i=0;
my $debug=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT items.biblionumber AS bibnum,itemnumber,marcxml FROM items 
                       LEFT JOIN biblioitems ON (items.biblionumber=biblioitems.biblionumber)
                       WHERE itemcallnumber = '';");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
    $i++;
    print ".";
    print "\r$i" unless ($i % 100);
    my $thisrec = eval { MARC::Record::new_from_xml( $rec->{'marcxml'}, "utf8", C4::Context->preference('marcflavour') ) };
    if (!$thisrec->field("090")){
       $debug and print "Skipping $rec->{'bibnum'} .. no 090.\n";
       $skipped++;
       next;
    }
    my $newcall = $thisrec->subfield("090","a")." ".$thisrec->subfield("090","b");
    C4::Items::ModItem({itemcallnumber => $newcall},$rec->{'bibnum'},$rec->{'itemnumber'});
    $edited++;
    $debug and print "\n$rec->{'bibnum'}\n";
    $debug and last;
}

print "$skipped records skipped.\n$edited records edited.\n\n";
