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
my $doo_eet=0;

GetOptions(
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

my $ok=0;
my $edited=0;
my $i=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT biblionumber FROM biblioitems");
$sth->execute();
my $sth2=$dbh->prepare("SELECT biblionumber,marc from biblioitems WHERE biblionumber=?");

while (my $rec=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $sth2->execute($rec->{'biblionumber'});
   my $cur_rec = $sth2->fetchrow_hashref();
   my $record = MARC::Record::new_from_usmarc( $cur_rec->{'marc'});
   if ($record->field('945')){
      $debug and print "\nCorrecting record $cur_rec->{'biblionumber'}:\n";
      foreach my $dumpfield($record->field('945')){
         $record->delete_field($dumpfield);
      }
      if ($doo_eet){
         C4::Biblio::ModBiblioMarc($record,$rec->{'biblionumber'}, "FA");
      }
      $edited++;
   } else {
      $ok++;
   }
}
 
print "$i\n\n";
print "$i records processed.\n$ok records were ok.\n$edited records edited.\n";
