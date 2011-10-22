#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# For all biblios, if no 090 field exists, this script will copy the 050 to 090, if 050 
# exists.
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
my $sth=$dbh->prepare("SELECT biblionumber,marcxml FROM biblioitems");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
    $i++;
    print ".";
    print "\r$i" unless ($i % 100);
    my $thisrec = eval { MARC::Record::new_from_xml( $rec->{'marcxml'}, "utf8", C4::Context->preference('marcflavour') ) };
    if (!$thisrec->field("710")){
       $debug and print "Skipping $rec->{'biblionumber'} .. no 710.\n";
       $skipped++;
       next;
    }
    if ($thisrec->subfield("710","a") !~ /NetLibrary/){
       $debug and print "Skipping $rec->{'biblionumber'} .. not NetLibrary.\n";
       $skipped++;
       next;
    }
    if ($thisrec->field("090")){
       $debug and print "Skipping $rec->{'biblionumber'} .. has an 090.\n";
       $skipped++;
       next;
    }
    if ($thisrec->field("099")){
       my $newtag = MARC::Field->new("090"," "," ",
                                     'a' => $thisrec->subfield("099","a"),
                                     'b' => $thisrec->subfield("099","b"));
       $thisrec->insert_grouped_field($newtag);
       ModBiblio($thisrec,$rec->{'biblionumber'});
       $edited++;
       $debug and print "Edited $rec->{'biblionumber'}!\n";
       $debug and last;
    }
    else{
       print "Biblionumber $rec->{'biblionumber'} has no 099 or 090 field.\n";
       $blocked++;
    }
}

print "$skipped records skipped.\n$edited records edited.\n$blocked records not edited due to lack of 050.\n\n";
