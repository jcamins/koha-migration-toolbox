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
#   -tag to delete
#
# DOES:
#   -trolls the Koha database for biblios containing a specified tag, and deletes them, if --update is specified
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be done, if --debug is specified
#   -count of biblios considered
#   -count of biblios modified

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

use C4::Context;
use C4::Biblio;
use MARC::Record;
use MARC::Field;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $tag = $NULL_STRING;

GetOptions(
    'tag=s'    => \$tag,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($tag) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber from biblio");
$sth->execute();

RECORD:
while (my $row = $sth->fetchrow_hashref()){
  $i++;
  print '.' unless ($i % 10);
  print "\r$i" unless ($i % 100);

  my $record = GetMarcBiblio($row->{biblionumber});
  next RECORD if (!$record->field($tag));

  foreach my $oldfield ($record->field($tag)) {
     $record->delete_field($oldfield);
  }

  $debug and print "Biblio $row->{biblionumber} will be edited.\n";

  if ($doo_eet){
     C4::Biblio::ModBiblio($record,$row->{biblionumber});
  }
  $written++;
}

print << "END_REPORT";

$i records read.
$written records modified.
END_REPORT

exit;

