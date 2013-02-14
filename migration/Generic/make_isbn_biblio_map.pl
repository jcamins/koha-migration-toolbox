#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

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
use MARC::Record;
use MARC::Field;
use MARC::Charset;
use Business::ISBN;
use Business::ISSN;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $output_filename = $NULL_STRING;

GetOptions(
    'out=s'         => \$output_filename,
    'debug'         => \$debug,
);

for my $var ($output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $dbh=C4::Context->dbh();
my $dum=MARC::Charset->ignore_errors(1);
my $sth=$dbh->prepare("SELECT biblionumber FROM biblioitems");
my $marc_sth=$dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
$sth->execute();

open my $out,'>',$output_filename;

RECORD:
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $marc_sth->execute($row->{biblionumber});
   my $rec = $marc_sth->fetchrow_hashref();
   my $marc;
   eval {$marc = MARC::Record->new_from_usmarc($rec->{marc}); };
   if ($@){
      print "bogus record skipped\n";
      next RECORD;
   }
FIELD020:
   foreach my $field ($marc->field('020')) {
      my $data = $field->subfield('a') || $NULL_STRING;
      $debug and print "Data: $data\n";
      next FIELD020 if $data eq $NULL_STRING;
      ($data, undef) = split / /,$data,2;
      my $isbn_in = Business::ISBN->new($data);
      next FIELD020 if !$isbn_in;
      if ($isbn_in->is_valid) {
         my $isbn_10 = $isbn_in->as_isbn10();
         next FIELD020 if !$isbn_10;
         $isbn_10->fix_checksum();
         print {$out} "$isbn_10->{isbn},$row->{biblionumber}\n";
         $written++;

         my $isbn_13 = $isbn_in->as_isbn13();
         next FIELD020 if !$isbn_13;
         $isbn_13->fix_checksum();
         print {$out} "$isbn_13->{isbn},$row->{biblionumber}\n";
         $written++;
      }
   }

FIELD022:
   foreach my $field ($marc->field('022')) {
      my $data = $field->subfield('a') || $NULL_STRING;
      $debug and print "Data: $data\n";
      next FIELD022 if $data eq $NULL_STRING;
      my $issn_in = Business::ISSN->new($data);
      next FIELD022 if !$issn_in;
      if ($issn_in->is_valid) {
         print {$out} "$issn_in->{issn},$row->{biblionumber}\n";
         $written++;
      }
   }
}

close $out;

print "\n$i records read from database.\n$written lines in output file.\n";

