#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
#  Scans for corrupted MARCXML.
#  Creates new MARC record from binary
#  MARC (more forgiving).
#  Removes fields without subfields.
#  Saved updated biblio
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;

$|=1;
my $debug=0;

GetOptions(
    'debug'         => \$debug,
);

my $ok=0;
my $edited=0;
my $i=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT biblionumber FROM biblioitems");
$sth->execute();
my $sth2=$dbh->prepare("SELECT biblioitems.biblionumber AS biblionumber,marc,marcxml,frameworkcode from biblioitems INNER JOIN biblio ON (biblio.biblionumber=biblioitems.biblionumber) where biblioitems.biblionumber=?");

while (my $rec=$sth->fetchrow_hashref()){
   $debug and last if ($edited>0);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $sth2->execute($rec->{'biblionumber'});
   my $cur_rec = $sth2->fetchrow_hashref();
   eval { MARC::Record::new_from_xml( $cur_rec->{'marcxml'}, "utf8", C4::Context->preference('marcflavour') ) };
   if ($@) {
	  my $thisrec = MARC::Record::new_from_usmarc( $cur_rec->{'marc'});
          $debug and print "\nCorrecting record $cur_rec:\n";
          $debug and warn Dumper($thisrec);
	  C4::Biblio::ModBiblioMarc($thisrec,$rec->{'biblionumber'}, $rec->{'frameworkcode'});
	  $edited++;
   } else {
	  $ok++;
   }
}
 
print "$i\n\n";
print "$i records processed.\n$ok records were ok.\n$edited records edited.\n";
