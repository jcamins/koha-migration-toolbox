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
#   -csv with borrowerbar, bibliobar, reservedate, and status, in any order
#
# DOES:
#   -creates reserve records, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be done, if --debug is set
#   -count of records read, inserts, and problems

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
use C4::Members;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $csv = Text::CSV_XS->new({ binary => 1 });
my $dbh = C4::Context->dbh();

my $bib_query      = $dbh->prepare("SELECT biblionumber FROM items WHERE barcode = ?");
my $item_query     = $dbh->prepare("SELECT biblionumber,itemnumber FROM items WHERE barcode = ?");
my $insert_query   = $dbh->prepare("INSERT INTO reserves (borrowernumber, reservedate, biblionumber, constrainttype,
                                                          branchcode,     priority,    found,        itemnumber)
                                                VALUES   (?, ?, ?, 'a', ?, 0, ?, ?)");

open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file));

RECORD:
while (my $line=$csv->getline_hr($input_file)){
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   my $borrower=GetMember(cardnumber => $line->{borrowerbar});
   if (!$borrower) {
      print "EXCEPTION: NO BORROWER\n";
      print Dumper($line);
      $problem++;
      next RECORD;
   }
   my $item;
   my $found = undef;
   if ($line->{status} eq 'Hold Shelf') {
      $item_query->execute($line->{bibliobar});
      $item=$item_query->fetchrow_hashref();
      $found = "W";
   }
   else {
      $bib_query->execute($line->{bibliobar});
      $item=$bib_query->fetchrow_hashref();
   }
   if (!$item) {
      print "EXCEPTION: NO ITEM/BIB\n";
      print Dumper($line);
      $problem++;
      next RECORD;
   }
   if ($doo_eet){
      $insert_query->execute($borrower->{borrowernumber}, $line->{reservedate}, $item->{biblionumber}, 
                             $borrower->{branchcode},     $found,               $item->{itemnumber});
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;

