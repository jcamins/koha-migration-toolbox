#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
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
#   -CSV of holds data
#   -maps for Voyager item and bib IDs
#   -optional flag to use item-specific holds
#
# DOES:
#   -inserts holds, if  --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be done, if --debug is set
#   -count of lines read
#   -count of holds inserted
#   -count of problems

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
use C4::Items;
use C4::Members;

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

my $input_filename       = $NULL_STRING;
my $item_id_map_filename = $NULL_STRING;
my $bib_id_map_filename  = $NULL_STRING;
my $item_specific_holds  = 0;

GetOptions(
    'in=s'          => \$input_filename,
    'item_map=s'    => \$item_id_map_filename,
    'bib_map=s'     => \$bib_id_map_filename,
    'item_specific' => \$item_specific_holds,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

for my $var ($input_filename,$item_id_map_filename,$bib_id_map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

print "reading item map...\n";
my %item_id_map;
if ($item_id_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$item_id_map_filename;
   while (my $line = $csv->getline($map_file)) {
      my @data= @$line;
      $item_id_map{$data[0]} = $data[1];
   }
   close $map_file;
}

print "reading bib map...\n";
my %bib_id_map;
if ($bib_id_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$bib_id_map_filename;
   while (my $line = $csv->getline($map_file)) {
      my @data= @$line;
      $bib_id_map{$data[0]} = $data[1];
   }
   close $map_file;
}

my $skipped = 0;
my $csv = Text::CSV_XS->new({ binary => 1 });
my $dbh = C4::Context->dbh();
my $insert_sth = $dbh->prepare("INSERT INTO reserves 
                                (borrowernumber, biblionumber, itemnumber, reservedate, branchcode, 
                                 priority, expirationdate, constrainttype)
                                 VALUES (?,?,?,?,?,?,?,'a')");
open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file));
RECORD:
while (my $line = $csv->getline_hr($input_file)) {
   last RECORD if ($debug && $written > 5);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   my $borrower = GetMember( 'cardnumber' => $line->{PATRON_BARCODE} );
   my $biblionumber = $bib_id_map{ $line->{BIB_ID} };
   if (!$borrower or !$biblionumber) {
      $problem++;
      next RECORD;
   }
   if ($line->{HR_STATUS_DESC} eq "Cancelled") {
      $skipped++;
      next RECORD;
   }

   my $itemnumber = undef;
   if ($item_specific_holds) {
      $itemnumber = GetItemnumberFromBarcode($line->{ITEM_BARCODE});
   }
   my $reservedate    = _process_date($line->{CREATE_DATE});
   my $expirationdate = _process_date($line->{EXPIRE_DATE});

   if ($debug) {
      print "BORR $borrower->{borrowernumber}/BIB $biblionumber/";
      if ($itemnumber) {
         print "ITEM $itemnumber/";
      }
      print "DATE $reservedate/EXPIRE $expirationdate/BRANCH $borrower->{branchcode}/PRIO $line->{QUEUE_POSITION}\n";
   }
   if ($doo_eet) {
      $insert_sth->execute($borrower->{borrowernumber},$biblionumber,$itemnumber,$reservedate,$borrower->{branchcode},
                           $line->{QUEUE_POSITION},$expirationdate);
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
$skipped cancelled holds skipped.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;

sub _process_date {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq "";
   my ($month,$day,$year) = $datein =~ /(\d+).(\d+).(\d\d\d\d)/;
   if ($month && $day && $year) {
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
   }
   else {
      return undef;
   }
}
