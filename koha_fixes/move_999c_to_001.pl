#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#  modified: Joy Nelson for MDAH 999$c to 001
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -trolls the Koha database for biblios containing a 440, and edits them in accordance
#    with LC standard to 490/830.
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
use C4::Context;
use C4::Biblio;
use MARC::Record;
use MARC::Field;

$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $new_only = 0;

GetOptions(
    'new_only' => \$new_only,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $written = 0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber from biblio");
$sth->execute();

RECORD:
while (my $row = $sth->fetchrow_hashref()){
  last RECORD if ($debug and $written > 5);
  $i++;
  print '.' unless ($i % 10);
  print "\r$i" unless ($i % 100);

  my $record = GetMarcBiblio($row->{biblionumber});
  next RECORD if !$record;
  next RECORD if (!$record->field(999));

  my $bibnum = $row->{biblionumber};

#delete existing 001 fields
  my @ctrlfield = $record->field('001');
  $record->delete_fields(@ctrlfield); 

#add new 001 fields
  my $newctrlfield = new MARC::Field('001',$bibnum);
  $record->insert_fields_ordered($newctrlfield);

  if ($debug){
     print "\n".Dumper($bibnum)."\n";
     print $record->as_formatted();
     print "\n";
  }

  if ($doo_eet){
     C4::Biblio::ModBiblio($record,$row->{biblionumber});
  }
  $written++;
}


print "\n\n$i records examined.\n$written records modified.\n";
