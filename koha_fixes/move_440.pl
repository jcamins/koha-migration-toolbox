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
  next RECORD if (!$record->field(440));

  my $oldfield = $record->field('440');

  my $suba = $oldfield->subfield('a') || "";
  my $subn = $oldfield->subfield('n') || "";
  my $subp = $oldfield->subfield('p') || "";
  my $newa = $suba.' '.$subn.' '.$subp;
  $newa =~ s/  / /g;
  $newa =~ s/\s+$//g;
  my $newfield = MARC::Field->new('490','1',' ','a'=>$newa);

  if ($oldfield->subfield('v')){
     $newfield->update('v'=>$oldfield->subfield('v'));
  }

  if ($oldfield->subfield('x')){
     $newfield->update('x'=>$oldfield->subfield('x'));
  }

  if ($oldfield->subfield('6')){
     $newfield->update('6'=>$oldfield->subfield('6'));
  }

  if ($oldfield->subfield('8')){
     $newfield->update('8'=>$oldfield->subfield('8'));
  }
  if (($new_only && !$record->field('490')) || !$new_only) {
     $record->insert_grouped_field($newfield);
  }

  my $newfield2 = MARC::Field->new('830',' ',' ','9'=>'1');
  $newfield2->update( ind1 => $oldfield->indicator(1) );
  $newfield2->update( ind2 => $oldfield->indicator(2) );
  foreach my $sub ($oldfield->subfields()){
     my ($code,$val) = @$sub;
     $newfield2->update( $code => $val );
  }
  $newfield2->delete_subfield( code => '9' );
  if (($new_only && !$record->field('830')) || !$new_only) {
     $record->insert_grouped_field($newfield2);
  }
  $record->delete_field($oldfield);

  if ($debug){
     print "\n".Dumper($oldfield)."\n";
     print $record->as_formatted();
     print "\n";
  }

  if ($doo_eet){
     C4::Biblio::ModBiblio($record,$row->{biblionumber});
  }
  $written++;
}


print "\n\n$i records examined.\n$written records modified.\n";
