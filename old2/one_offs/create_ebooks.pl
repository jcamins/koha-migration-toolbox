#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# This script will cleverly create new EBOOK items for biblios that do not have one.
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
my $i=2;
my $debug=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT biblioitems.biblionumber AS biblionumber,marcxml FROM biblioitems 
                       LEFT JOIN items ON (biblioitems.biblionumber=items.biblionumber) 
                       WHERE items.itemnumber IS NULL AND biblioitems.itemtype='EBOOK';
                       ");
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
    my $barcode = sprintf("EBOOK%09d",$i);

    C4::Items::AddItem({ barcode => $barcode,
                         itemcallnumber => $newcall,
                         notforloan     => 3,
                         itype          => "EBOOK",
                         homebranch     => "MAIN",
                         holdingbranch  => "MAIN",
                         cn_source      => "lcc"},$rec->{'biblionumber'});
    $edited++;
    $debug and print "\n$rec->{'biblionumber'}\n";
    $debug and last;
}

print "$skipped records skipped.\n$edited records created.\n\n";
