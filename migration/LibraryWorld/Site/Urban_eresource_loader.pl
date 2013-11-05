#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -Joy Nelson
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -trolls the biblio database for 245$h[electronic resource] 
#     then add itemrecord to items
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of biblios considered
#   -count of biblios modified

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;
use C4::Items;

$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $bibitemrec;
my $bibitemnum;
my $subu;
my $ebib;
my $written = 0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber from biblio");
my $bibitem_sth = $dbh->prepare("SELECT biblioitemnumber from biblioitems where biblionumber=?");
my $eresource_sth = $dbh->prepare("INSERT into items (biblionumber, biblioitemnumber, dateaccessioned, homebranch, itemcallnumber, holdingbranch, itype) VALUES (?,?,NOW(),?,?,?,'EBOOK')");
my $items_exist_sth = $dbh->prepare("SELECT itemnumber from items where biblionumber =?");

$sth->execute();


RECORD:
while (my $row = $sth->fetchrow_hashref()){
  last RECORD if ($debug and $written > 10000);
  $i++;
  print '.' unless ($i % 10);
  print "\r$i" unless ($i % 100);

  my $tags = 0;
  my $modified = 0;
  

  my $record = GetMarcBiblio($row->{biblionumber});
  next RECORD if (!$record->subfield('245','h'));

  foreach my $tag ($record->field(245)){
     $tags++;
     $subu = $tag->subfield('h') || "";
     if ($subu =~ m/lectronic/)  {
        $ebib = $row->{biblionumber};

        $bibitem_sth->execute($ebib);
        $bibitemrec=$bibitem_sth->fetchrow_hashref();
        $bibitemnum = $bibitemrec->{biblioitemnumber};

        $modified=1;
     }
  }
  next RECORD if ($modified == 0);

  my $items = GetItemsCount($ebib);

  if ($debug){
     print "\n$ebib : $bibitemnum : $items : $subu\n";
  }


  if ($doo_eet && $modified){
     my $itemnumbers = GetItemnumbersForBiblio($ebib);
     if ($items == 0) {
       $eresource_sth->execute($ebib,$bibitemnum,'URBAN','ONLINE','URBAN');
     }
     if ($items >0) {
       my $item_update_sth = $dbh->prepare("UPDATE items set itype='EBOOK' where biblionumber=?");
       $item_update_sth->execute($ebib);
     }
  }
  $written++;
}

print "\n\n$i records examined.\n$written records modified.\n";

