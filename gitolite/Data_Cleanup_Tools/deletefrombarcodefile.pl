#!/usr/bin/perl

# This script deletes items from a barcode file input
# Biblios with no remaining items are also deleted
# Uses Koha's native Delete interface, moving the records to the old_ tables
# and removing them from the Zebra index

# possible modules to use
use Getopt::Long;
use C4::Context;
use C4::Items;
use C4::Biblio;

# Benchmarking variables
my $startime = time();
my $usecount = 0;
my $testmode;
my $filename;

GetOptions(
  't'	=> \$testmode,
  'f:s' => \$filename
);

# input from file, output log
open(IN, "$filename") || die ("Cannot open input file");
my $dbh = C4::Context->dbh;

# fetch info from IN file
while (<IN>){
  chomp();
  my $barcode = $_;
  
  if (defined $testmode) {
     print "barcode: ($barcode)\n";
  } else {
    my $sth = $dbh->prepare("SELECT biblionumber, itemnumber from items WHERE barcode = ?");
    $sth->execute($barcode);
    my $row = $sth->fetchrow_hashref();
    my $biblionumber = $row->{'biblionumber'};
    my $itemnumber = $row->{'itemnumber'};
    if ($biblionumber && $itemnumber) {
      my $error_item = DelItem($dbh, $biblionumber, $itemnumber);
      my $error_bib = DelBiblio($biblionumber);
    }

    # increment for benchmarking
    $usecount++;

    # report on progress
    print "Error with item $itemnumber: $error_item\n" if ($error_item);
    print "Error with bib $biblionumber: $error_bib\n" if ($error_bib);
  }
}

# Benchmarking
my $endtime = time();
my $time = $endtime-$startime;
print "Total of $usecount records modified in $time seconds\n";
