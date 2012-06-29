#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# - Joy Nelson
#   modified from load_borrower_lists.pl
#---------------------------------
#
# EXPECTS:
#   -delimited file with reference to borrower,  biblioid, itembarcode
#
# DOES:
#   -creates and populates borrower lists, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -counts of shelves and list entries created

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
use C4::VirtualShelves;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename    = $NULL_STRING;

GetOptions(
    'in=s'        => \$input_filename,
    'debug'       => \$debug,
    'update'      => \$doo_eet,
);

for my $var ($input_filename) {
   croak ('You are missing something') if $var eq $NULL_STRING;
}

my $dbh         = C4::Context->dbh();
my $item_sth    = $dbh->prepare("SELECT biblionumber from items where barcode =?");
my $borr_sth    = $dbh->prepare("SELECT borrowernumber from borrowers where cardnumber = ?");
my $shelf_q     = $dbh->prepare("SELECT shelfnumber FROM virtualshelves WHERE owner=?");
my $shelf_added = 0;
my $problem_2   = 0;
my $this_bibnum = 0;
my $this_borrnum =0;

my $csv=Text::CSV_XS->new({binary => 1});
open my $input_file,'<',$input_filename;
RECORD:
while (my $line = $csv->getline($input_file)){
   last RECORD if ($debug and $i > 20);
   $i++;
   print q{.}    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;

   # Gather the bib number and borrowernumber.

   my $this_item = $data[2];
   if ($this_item) {
     $item_sth->execute($this_item);
     my $db_item_fetch=$item_sth->fetchrow_hashref();
     $this_bibnum=$db_item_fetch->{'biblionumber'};
   }
   else {
      print "\nBarcode $data[2] not found!\n";
      $problem++;
      next RECORD;
   }
   if (!$this_bibnum) {
      print "\nBarcode $data[2] not found!\n";
      $problem++;
      next RECORD;
   }

   my $this_borr =  $data[0];
   if ($this_borr) {
      $borr_sth->execute($this_borr);
      my $db_borr_fetch=$borr_sth->fetchrow_hashref();
      $this_borrnum=$db_borr_fetch->{'borrowernumber'};   
   }
   else {
      print "\nBorrower $data[0] not found!\n";
      $problem_2++;
      next RECORD;
   }
   if (!$this_borrnum) {
      print "\nBarcode $data[0] not found!\n";
      $problem_2++;
      next RECORD;
   }

   # Find out if the shelf exists.  If it does, get the shelfnumber; if not, add it.

   $shelf_q->execute($this_borrnum);
   my $shelf = $shelf_q->fetchrow_hashref();
   my $shelfnum = $shelf->{'shelfnumber'};
   if ($shelfnum) {
#     print "existing shelf: $shelfnum\n";
   }
   else {
     if ($doo_eet) {
      $shelfnum = AddShelf('Patron Book List',$this_borrnum,1,'title');
      }
      $shelf_added++;
   }
   $shelf_q->execute($this_borrnum);
   $shelf = $shelf_q->fetchrow_hashref();
   $shelfnum = $shelf->{'shelfnumber'};
   
# Add the bib to the shelf.

   if ($doo_eet) {
      AddToShelf($this_bibnum,$shelfnum);
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$shelf_added virtual shelves created.
$written items added to shelves.
$problem records not loaded -- Biblio not found.
$problem_2 records not loaded -- Borrower not found.
END_REPORT

exit;

