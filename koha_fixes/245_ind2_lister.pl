#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -Joy Nelson, edited
#    pulls a list of titles and indicator 2
#      written for SF Maritime to check indicator 2 value
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use MARC::Charset;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;
my $val="";

GetOptions(
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);


my $dbh=C4::Context->dbh();
my $i=0;

my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');

my $marc_sth = $dbh->prepare("SELECT biblionumber, marc FROM biblioitems where biblionumber<>34943");
$marc_sth->execute();

RECORD:
while (my $thisrec=$marc_sth->fetchrow_hashref()){
   last RECORD if (($debug) && ($i>10) );
   $i++;
#   print ".";
#   print "\r$i" unless ($i % 100);

#   my $marcrec = $marc_sth->fetchrow_hashref();
   my $bib = $thisrec->{'biblionumber'};

   my $rec;
   eval{ $rec = MARC::Record::new_from_usmarc($thisrec->{'marc'});};
   if ($@){
      print "\n Error in biblio $thisrec->{'biblionumber'}\n";
      next;
   }
   my $field=$rec->field('245');
   my $ind_two=$field->indicator('2');

   if ($field){
      my $curval = $field->subfield("a") || "";
      if ($curval ne $val){
         print "$bib | $ind_two | $curval \n";
      }
   }
}
print "\n\n$i records examined.\n";

