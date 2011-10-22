#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# For all biblios hooked to EBOOK items, dump 856$3, and make sure that 856$z says what we want it to.
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use C4::Context;
use C4::Biblio;
use MARC::Record;

my $skipped=0;
my $edited=0;
my $blocked=0;
my $i=0;
my $debug=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT biblioitems.biblionumber AS biblionumber,marcxml FROM biblioitems
                       LEFT JOIN items ON (biblioitems.biblionumber=items.biblionumber)
                       WHERE items.itype='EBOOK'");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
    $i++;
    print ".";
    print "\r$i" unless ($i % 100);
    my $thisrec = eval { MARC::Record::new_from_xml( $rec->{'marcxml'}, "utf8", C4::Context->preference('marcflavour') ) };
    if (!$thisrec->field("856")){
       $debug and print "Skipping $rec->{'biblionumber'} .. no 856!.\n";
       $blocked++;
       next;
    }
    if ($thisrec->subfield("856","3") && $thisrec->subfield("856","z")){
       my $newtag = MARC::Field->new("856",$thisrec->field("856")->indicator(1),$thisrec->field("856")->indicator(2),
                                     'u' => $thisrec->subfield("856","u"),
                                     'z' => $thisrec->subfield("856","z"));
       $thisrec->delete_field($thisrec->field("856"));
       $thisrec->insert_grouped_field($newtag);
       ModBiblio($thisrec,$rec->{'biblionumber'});
       $edited++;
       $debug and print "Edited $rec->{'biblionumber'}!\n";
       $debug and last;
    }
    else{
       $debug and print "Biblionumber $rec->{'biblionumber'} looks okay.\n";
       $skipped++;
    }
}

print "$skipped records already looked fine.\n$edited records edited.\n$blocked records not edited due to lack of 856.\n\n";

