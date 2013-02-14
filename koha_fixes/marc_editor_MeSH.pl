#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#   -11-29-2012 jen only look for MeSH indicators (2nd indicator=2)
#   -12-13-2012 jen added functionality to read a map file of old->new MeSH headings instead of old/new runtime options
#
#---------------------------------
#
# EXPECTS:
#   -tag/subfield to edit
#   -file of old and new values
#
# DOES:
#   -trolls the Koha database for biblios containing a specified tag, and edits them, if --update is specified
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
my $sub = $NULL_STRING;
my $mesh_mapfile='';
my %mesh_map;


GetOptions(
    'tag=s'    => \$tag,
    'sub=s'    => \$sub,
    'meshfile=s'  => \$mesh_mapfile,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if ($tag < 10) {
   croak ("This script really is not intended for tags 000-009. That'd be way dangerous.");
}

for my $var ($tag,$sub,$mesh_mapfile) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if ($mesh_mapfile){
   my $csv = Text::CSV_XS->new();
   open my $mapfile,"<$mesh_mapfile";
   while (my $row = $csv->getline($mapfile)){
      my @data=@$row;
      $mesh_map{$data[0]} = $data[1];
   }
   close $mapfile;
}


my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber from biblio;");
$sth->execute();

RECORD:
while (my $row = $sth->fetchrow_hashref()){
  last RECORD if ($debug and $written >4000);
  $i++;
  print '.' unless ($i % 10);
  print "\r$i" unless ($i % 100);

  my $record;
  eval {$record = GetMarcBiblio($row->{biblionumber}); };
  if ($@) {
     print "Problem with record $row->{biblionumber}\n";
     next RECORD;
  }
  next RECORD if (!$record->subfield($tag,$sub));

$debug and print "biblio -> $row->{biblionumber}\n";

foreach my $tagtocheck ($record->field($tag)) {

   my $second_ind = $tagtocheck->indicator(2);
$debug and print "second indicator -> $second_ind\n";
   next if ($second_ind ne 2);

   my $old_value = $tagtocheck->subfield($sub);
$debug and print "old value - > $old_value\n";

   if (exists $mesh_map{$old_value}) {
     $tagtocheck->update( $sub => $mesh_map{$old_value} );

     $debug and print "Biblio $row->{biblionumber} will be edited.\n";
     $debug and print "$old_value --> $mesh_map{$old_value}\n";

     if ($doo_eet){
        C4::Biblio::ModBiblio($record,$row->{biblionumber});
     }
     $written++;
  }
 } #end foreach loop
}

print << "END_REPORT";

$i records read.
$written records modified.
END_REPORT

exit;

