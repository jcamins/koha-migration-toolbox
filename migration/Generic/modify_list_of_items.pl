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
#   -input CSV of barcodes
#   -optional map from item identifiers to barcodes
#   -which value is to be changed
#   -new value
#
# DOES:
#   -updates the value described, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of items modified
#   -count of items not modified due to missing barcode
#   -details of what will be changed, if --debug is set

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Items;
$|=1;
my $debug = 0;
my $doo_eet = 0;
my $i=0;

my $infile_name = q{};
my $field_to_change = q{};
my $csv_delim            = 'comma';
my $new_value = q{};
my $mapfile_name = q{};

GetOptions(
   'in:s'     => \$infile_name,
   'field:s'  => \$field_to_change,
   'value:s'  => \$new_value,
   'map=s'    => \$mapfile_name,
'delimiter=s'  => \$csv_delim,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if (($infile_name eq q{}) || ($field_to_change eq q{})){
   print "Something's missing.\n";
   exit;
}

my %item_map;
if ($mapfile_name ne q{}) {
   print "Reading map file...\n";
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$mapfile_name;
   while (my $line = $csv->getline($map_file)) {
      my @data = @$line;
      $item_map{$data[0]} = $data[1];
   }
   close $map_file;
}

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                );
my $written=0;
my $item_not_found=0;
my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $delimiter{$csv_delim} });
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber FROM items WHERE barcode = ?");
open my $infl,"<",$infile_name;

RECORD:
while (my $line=$csv->getline($infl)){
   last RECORD if ($debug and $i>10);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line; 
   my $barcode = $data[0];
   if (defined $item_map{$barcode}) {
      $barcode = $item_map{$barcode};
   }
   $sth->execute($barcode);
   my $rec=$sth->fetchrow_hashref();

   if (!$rec){
      $item_not_found++;
      next RECORD;
   }

   $debug and print "$barcode ($rec->{itemnumber})  $field_to_change => $new_value\n";

   if ($doo_eet){
      C4::Items::ModItem({ $field_to_change => $new_value },undef,$rec->{'itemnumber'});
   }
   $written++;
}
close $infl;
print "\n\n$i records read.\n$written items updated.\n$item_not_found not updated due to unknown barcode.\n";

exit;

