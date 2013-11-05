#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
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
my $doo_eet=0;
my $i=0;

my $days=0;
my $written=0;
my $ignore_url=0;
my $silent=0;

GetOptions(
    'days=s'        => \$days,
    'ignore_url'    => \$ignore_url,
    'silent'        => \$silent,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

my $dbh=C4::Context->dbh();
my $query = "SELECT biblio.biblionumber, biblio.title, biblio.datecreated FROM biblio
                       LEFT JOIN items ON (biblio.biblionumber=items.biblionumber)
                       JOIN biblioitems ON (biblio.biblionumber=biblioitems.biblionumber)
                       WHERE items.itemnumber IS NULL";
if (!$ignore_url){
   $query .= " AND biblioitems.url IS NULL";
}
if ($days){
   $query .= " AND datecreated < ADDDATE(CURDATE(),-$days)";
}
$debug and print "Q: $query\n";
my $sth=$dbh->prepare($query);
$sth->execute();
while (my $rec=$sth->fetchrow_hashref()){
   last if ($debug and $i>200000);
   $i++;
   print "." unless ($i % 10) or $silent;
   print "\r$i" unless ($i % 100) or $silent;
   $debug and print "Biblio:  $rec->{'biblionumber'}   title: $rec->{'title'}   datecreated: $rec->{'datecreated'}\n";
   if ($doo_eet){
      my $err = C4::Biblio::DelBiblio($rec->{'biblionumber'});
      print "Problem deleting biblio $rec->{'biblionumber'}\n" if $err;
      $written++ if (!$err);
   }
}

print "\n\n$i biblios found.\n$written biblios deleted.\n" unless $silent;

