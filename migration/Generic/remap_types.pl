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
#   -CSV with old and new item types, and optional location and collection codes
#   -option flag to force overlay of location and collection codes
#
# DOES:
#   -updates item type, location, and collection codes, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is set
#   -count of map lines read
#   -count of items modified

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

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = $NULL_STRING;
my $override       = 0;

GetOptions(
    'in=s'     => \$input_filename,
    'override' => \$override,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $dbh        = C4::Context->dbh();
my $select_sth = $dbh->prepare("SELECT itemnumber,location,ccode FROM items WHERE itype=?");

my $csv = Text::CSV_XS->new({ empty_is_undef => 1 });
$csv->column_names("old_itype","new_itype","location","ccode");

my $total_items_read = 0;

open my $input_file,'<',$input_filename;
LINE:
while (my $line=$csv->getline_hr($input_file)) {
   $i++;

   $select_sth->execute($line->{old_itype});
   $total_items_read += $j;
   $j                 = 0;
   print "\nInput Map $i:\n";
ITEM:
   while (my $record=$select_sth->fetchrow_hashref()) {
      #last ITEM if ($debug and $j>0);
      $j++;
      print '.'    unless ($j % 10);
      print "\r$j" unless ($j % 100);

      my $item = {};
      $item->{itype} = $line->{new_itype};
      if ($override) {
         if ($line->{location}) {
            $item->{location} = $line->{location};
         }
         if ($line->{ccode}) {
            $item->{ccode}    = $line->{ccode};
         }
      }
      else {
         if (!$record->{location}) {
            $item->{location} = $line->{location};
         }
         if (!$record->{ccode}) {
            $item->{ccode}    = $line->{ccode};
         }
      }
      $debug and print "Item $record->{itemnumber} ($record->{location}, $record->{ccode}) to be changed as follows:\n";
      $debug and print Dumper($item);
      if ($doo_eet) {
         $debug and print "Calling ModItem!\n";
         ModItem($item,undef,$record->{itemnumber});
      }
      $written++;
   }
}
close $input_file;
$total_items_read += $j;

print << "END_REPORT";

$i map records read.
$total_items_read items examined.
$written items modified.
END_REPORT

exit;
