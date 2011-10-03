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
#   -input file of barcodes
#   -new biblionumber to move to
#
# DOES:
#   -moves specified items to new biblionumber
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of items read from file
#   -count of items moved

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $input_filename   = q{};
my $new_biblionumber = 0;

GetOptions(
    'in=s'     => \$input_filename,
    'biblio=i' => \$new_biblionumber,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($input_filename eq q{}) || ($new_biblionumber == 0)) {
   print "You're missing something.\n";
   exit;
}

my $items_moved = 0;
open my $in, "<", $input_filename;

BARCODE:
while (my $barcode = readline($in)) {
   chomp $barcode;
   $barcode =~ s///g;
   $i++;
   print q{.}   unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $item = GetItem(undef,$barcode);
   $debug and print "Moving $barcode ($item->{itemnumber} from $item->{biblionumber} to $new_biblionumber.\n";
   if ($doo_eet) {
      my $result = MoveItemFromBiblio($item->{itemnumber}, $item->{biblionumber}, $new_biblionumber);
   }
   $items_moved++;
}

print "\n\n$i records read.\n$items_moved items moved.\n";
