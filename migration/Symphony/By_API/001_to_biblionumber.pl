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
#   -nothing
#
# CREATES:
#   -output file in CSV form:
#      <old MARC num from 001>,<biblionumber>
#
# REPORTS:
#   -nothing

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Biblio;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;


my $output_filename = q{};

GetOptions(
    'out=s'    => \$output_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if ($output_filename eq q{}) {
   print "You're missing something.\n";
   exit;
}

my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber FROM biblioitems");
$sth->execute();
open my $out, '>', $output_filename;

BIBLIO:
while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print q{.} unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $marc_record = GetMarcBiblio($row->{biblionumber});
   my $old_marcnumber;
   if ($marc_record->field('001')){
      $old_marcnumber = $marc_record->field('001')->data();
   }
   if ($old_marcnumber) {
      print {$out} "$old_marcnumber,$row->{biblionumber}\n";
   }
}
close $out;

print "\n\n$i records output.\n";

