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
use Data::Dumper;
use Getopt::Long;
use C4::Context;
use C4::Items;
use C4::Dates;
$|=1;
my $debug=0;

GetOptions(
    'debug'           => \$debug,
);

#if (($infile_name eq '')){
#  print "Something's missing.\n";
#  exit;
#}

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,issuedate,date_due FROM issues");
$sth->execute();
my $i=0;
while (my $rec = $sth->fetchrow_hashref()){
   last if ($debug and $i>0);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
 
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

print "\n$i items modified\n";

