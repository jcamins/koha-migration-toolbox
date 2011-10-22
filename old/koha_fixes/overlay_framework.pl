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

$|=1;
my $debug=0;
my $doo_eet=0;
my $from = undef; 
my $to = undef;

GetOptions(
    'from=s'  => \$from,
    'to=s'    => \$to,
    'debug'   => \$debug,
    'update'  => \$doo_eet,
);

if (!$from || !$to){
   print "Something's missing.\n";
   exit;
}

exit;

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
   my $this_modified=0;
   $sth2->execute($rec->{'biblionumber'});
   my $cur_rec = $sth2->fetchrow_hashref();
   my $thisrec;
   eval { $thisrec = MARC::Record::new_from_xml( $cur_rec->{'marcxml'}, "utf8", C4::Context->preference('marcflavour') ) };
   if ($thisrec->field($droptag)){
      foreach (my $field = $thisrec->field($droptag)){
         if ($field->subfield($dropsub)){
            $field->delete_subfield($dropsub);
            $this_modified=1;
         }
      }
   }
   if ($this_modified){
      $debug and print "\nCorrecting record $cur_rec:\n";
      $debug and warn Dumper($thisrec);
      warn "Calling ModBiblioMarc";
      C4::Biblio::ModBiblioMarc($thisrec,$rec->{'biblionumber'}, $rec->{'frameworkcode'});
      $edited++;
   } else {
      $ok++;
   }
}
 
print "$i\n\n";
print "$i records processed.\n$ok records were ok.\n$edited records edited.\n";
