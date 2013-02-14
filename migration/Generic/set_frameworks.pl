#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
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
#   -updates framework codes on biblios, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is set
#   -count of records examined
#   -count of records modified

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

my $input_filename = "";

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my %FRAME_MAP = ( 'ab' => 'SER',
                  'ai' => 'SER',
                  'as' => 'SER',
                  'a*' => 'BKS',
                  'c*' => 'BKS',
                  'd*' => 'BKS',
                  'e*' => '',
                  'f*' => '',
                  'g*' => 'VR',
                  'i*' => 'SR',
                  'j*' => 'SR',
                  'k*' => 'VR',
                  'm*' => 'CF',
                  'o*' => 'VR',
                  'p*' => 'KT',
                  'q*' => '',
                  'r*' => 'VR',
                  't*' => 'BKS',
                );

my $dbh      = C4::Context->dbh();
my $bib_sth  = $dbh->prepare("SELECT biblionumber FROM biblioitems");
my $marc_sth = $dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber = ?");

$bib_sth->execute();
RECORD:
while (my $bib=$bib_sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $this_biblio = $bib->{biblionumber};
   $marc_sth->execute($this_biblio);
   my $marc = $marc_sth->fetchrow_hashref();
   my $rec;
   eval{ $rec = MARC::Record::new_from_usmarc($marc->{'marc'});};
   if ($@){
      print "\n Error in biblio $this_biblio\n";
      $problem++;
      next;
   }
   my $rec_type  = substr($rec->leader(),6,1);
   my $bib_level = substr($rec->leader(),7,1);
   my $new_framework = exists $FRAME_MAP{$rec_type.$bib_level} ? $FRAME_MAP{$rec_type.$bib_level}
                     : exists $FRAME_MAP{$rec_type.'*'}        ? $FRAME_MAP{$rec_type.'*'}
                     :                                           $NULL_STRING; 
   $debug and print "Changing biblio $this_biblio to $new_framework.\n";
   if ($doo_eet) {
      ModBiblioframework($this_biblio,$new_framework);
   }
   $written++;
}

print << "END_REPORT";

$i records read.
$written records updated.
$problem records not modified due to problems.
END_REPORT

exit;
