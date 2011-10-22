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
use Getopt::Long;
use C4::Context;
use C4::Biblio;
$|=1;
my $debug=0;
my $i=0;

my $days=0;
my $written=0;

GetOptions(
    'days=s'        => \$days,
    'debug'         => \$debug,
);

my $dbh=C4::Context->dbh();
my $sth;
if ($days){
   $sth=$dbh->prepare("SELECT biblio.biblionumber FROM biblio 
                       LEFT JOIN items ON (biblio.biblionumber=items.biblionumber)
                       WHERE items.biblionumber IS NULL
                       AND datecreated < ADDDATE(CURDATE(),-?);");
   $sth->execute($days);
}
else {
   $sth=$dbh->prepare("SELECT biblio.biblionumber FROM biblio 
                       LEFT JOIN items ON (biblio.biblionumber=items.biblionumber)
                       WHERE items.biblionumber IS NULL;");
    $sth->execute();
}
while (my $rec=$sth->fetchrow_hashref()){
   last if ($debug and $i>0);
   $i++; 
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "Biblio:  $rec->{'biblionumber'}\n";
   my $err = C4::Biblio::DelBiblio($rec->{'biblionumber'});
   print "Problem deleting biblio $rec->{'biblionumber'}\n" if $err;
   $written++ if (!$err);
}

print "\n\n$i biblios found.\n$written biblios deleted.\n";
