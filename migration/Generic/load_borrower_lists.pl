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
#   -delimited file with reference to borrower, list name, and biblio
#   -inputs about which column is which
#   -map from whatever is in the file to biblionumber
#   -map from whatever is in the file to borrowernumber
#   -delimiter (Defaults to 'comma')
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
my $csv_delim         = 'comma';
my $bib_map_filename  = $NULL_STRING;
my $borr_map_filename = $NULL_STRING;
my $borr_col          = $NULL_STRING;
my $name_col          = $NULL_STRING;
my $bib_col           = $NULL_STRING;

GetOptions(
    'in=s'        => \$input_filename,
    'delimiter=s' => \$csv_delim,
    'borr_map=s'  => \$borr_map_filename,
    'bib_map=s'   => \$bib_map_filename,
    'borr=i'      => \$borr_col,
    'name=i'      => \$name_col,
    'bib=i'       => \$bib_col,
    'debug'       => \$debug,
    'update'      => \$doo_eet,
);

my %DELIMITER = ( 'comma' => q{,},
                  'tab'   => "\t",
                  'pipe'  => q{|},
                );

for my $var ($input_filename,$bib_map_filename,$borr_map_filename,$borr_col,$name_col,$bib_col,$csv_delim) {
   croak ('You are missing something') if $var eq $NULL_STRING;
}

my %borr_map;
if ($borr_map_filename ne $NULL_STRING) {
   open my $map,'<',$borr_map_filename;
   my $csv = Text::CSV_XS->new({binary => 1});
   while (my $row=$csv->getline($map)) {
      my @data= @{$row};
      $borr_map{$data[0]} = $data[1];
   }
   close $map;
}

my %biblio_map;
if ($bib_map_filename ne $NULL_STRING) {
   open my $map,'<',$bib_map_filename;
   my $csv = Text::CSV_XS->new({binary => 1});
   while (my $row=$csv->getline($map)) {
      my @data= @{$row};
      $biblio_map{$data[0]} = $data[1];
   }
   close $map;
}

my $dbh         = C4::Context->dbh();
my $shelf_q     = $dbh->prepare('SELECT shelfnumber FROM virtualshelves WHERE owner=? AND shelfname=?');
my $shelf_added = 0;
my $problem_2   = 0;

my $csv=Text::CSV_XS->new({binary => 1, sep_char => $DELIMITER{$csv_delim}});
open my $input_file,'<',$input_filename;
RECORD:
while (my $line = $csv->getline($input_file)){
   last RECORD if ($debug and $i > 20);
   $i++;
   print q{.}    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @{$line};

   # Gather the bib number and borrowernumber.

   $debug and print Dumper(@data);

   my $this_bibnum = $biblio_map{$data[$bib_col]} || undef;
   if (!$this_bibnum) {
      print "\nBiblio $data[$bib_col] not found!\n";
      $problem++;
      next RECORD;
   }

   my $this_borrnum =  $borr_map{$data[$borr_col]} || undef;
   if (!$this_borrnum) {
      print "\nBorrower $data[$borr_col] not found!\n";
      $problem_2++;
      next RECORD;
   }

   # Find out if the shelf exists.  If it does, get the shelfnumber; if not, add it.

   $shelf_q->execute($this_borrnum,$data[$name_col]);
   my $shelf = $shelf_q->fetchrow_hashref();
   my $shelfnum;
   if ($shelf) {
      $shelfnum = $shelf->{shelfnumber};
   }
   else {
      if ($doo_eet) {
         $shelfnum = AddShelf($data[$name_col],$this_borrnum,1,'title');
      }
      $shelf_added++;
   }

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

