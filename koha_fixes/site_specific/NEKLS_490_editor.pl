#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -trolls the biblio database for 856$u that contain 'catalog', and edits that term to proxy.
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

$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $written = 0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber from biblio");
$sth->execute();

RECORD:
while (my $row = $sth->fetchrow_hashref()){
  last RECORD if ($debug and $i > 999999);
  $i++;
  print '.' unless ($i % 10);
  print "\r$i" unless ($i % 100);

  my $tags = 0;
  my $modified = 0;
  

  my $record = GetMarcBiblio($row->{biblionumber});
  next RECORD if (!$record->field(490));

  foreach my $tag ($record->field(490)){
     $tags++;
     my $ind = $tag->indicator(1) || "";
     if  ($ind eq "1" ){
        $tag->update( ind1 => '0');
        $modified=1;
     }
  }

  next RECORD if (!$modified);

  if ($debug){
     print $record->as_formatted();
     print "\n";
  }

  if ($doo_eet && $modified){
     C4::Biblio::ModBiblio($record,$row->{biblionumber});
  }
  $written++;
}

print "\n\n$i records examined.\n$written records modified.\n";

