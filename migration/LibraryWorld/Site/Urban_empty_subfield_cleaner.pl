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
#   -updates MARC and MARCXML to remove empty subfields, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be done, if --debug is set
#   -count of records considered
#   -count of records updated

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use MARC::Record;
use MARC::File::XML;
use MARC::Field;
use C4::Context;
use C4::Biblio;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

#for my $var ($input_filename) {
#   croak ("You're missing something") if $var eq $NULL_STRING;
#}

my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber,frameworkcode FROM biblio where biblionumber=6109");
my $marc_sth = $dbh->prepare("SELECT marcxml FROM biblioitems WHERE biblionumber = ?");
$sth->execute();

LINE:
while (my $rec=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   $marc_sth->execute($rec->{biblionumber});
   my $xml_sth = $marc_sth->fetchrow_hashref();
   my $record_in=$xml_sth->{marcxml};
   my $orig_len = length($record_in);

   #$debug and print $record_in."\n";
   $record_in =~ s/    \<subfield code="."\>\<\/subfield\>\n//g;
   $record_in =~ s/  \<datafield tag="..." ind1="." ind2="."\>\n  \<\/datafield\>//g;

   if (length($record_in) != $orig_len) {
      my $record;
      eval {$record = MARC::Record::new_from_xml($record_in);};
      if ($@){
         $problem++;
         next LINE;
      }
      $debug and print "Updating record $rec->{biblionumber}\n";
      if ($doo_eet){
         C4::Biblio::ModBiblioMarc($record,$rec->{'biblionumber'}, $rec->{'frameworkcode'});
      }
      $written++;
   }
}

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;
