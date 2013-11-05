#!/usr/bin/perl
#---------------------------------
# Copyright 2013 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# 
# Modification log: (initial and date)
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -creates items, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be done, if --debut is set
#   -number of bibs examined
#   -number of items created

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use C4::Context;
use C4::Biblio;
use C4::Items;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;


GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber FROM biblioitems ORDER BY biblionumber");
$sth->execute();

BIB:
while (my $bib_number=$sth->fetchrow_array()) {
   last BIB if ($debug and $written >10);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $record=GetMarcBiblio($bib_number);
   next BIB if !$record;
   my $mat_type = $record->subfield('245','h') || $NULL_STRING;
   next BIB if $mat_type !~ /electronic resource/;
   $debug and say "\n$bib_number";
   $written++;
   if ($doo_eet) {
      C4::Items::AddItem({ homebranch     => 'LIBRARY',
                           holdingbranch  => 'LIBRARY',
                           itype          => 'ELECTRONIC',
                           barcode        => $bib_number.'-1001',
                            }, $bib_number);
   }
}

print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
