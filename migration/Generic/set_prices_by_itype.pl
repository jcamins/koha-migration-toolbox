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
#   -CSV map of item types and default prices
#
# DOES:
#   -updates the price and replacement value on all items with zero values there, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of items modified
#   -details of what will be changed, if --debug is set

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
my $written = 0;
my $problem = 0;

my $input_filename = "";

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %price_map;
my $csv=Text::CSV_XS->new();
open my $input_file,'<',$input_filename;
while my $line=($csv->getline($input_file)) {
   my @data = @$line;
   $price_map{$data[0]} = $data[1];
}
close $input_file;

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,itype FROM items WHERE price=0 AND replacementprice=0");

RECORD:
while (my $record=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $i>100);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);

   if (exists $price_map{$record->{itype}}) {
      my $price =  $price_map{$record->{itype}};
      $debug and print "Updating item $record->{itemnumber} ($record->{itype}) to $price\n";
      if ($doo_eet){
         C4::Items::ModItem({ price => $price },undef,$record->{'itemnumber'});
      }
      $written++;
   }
}

print << "END_REPORT";

$i records read.
$written records modified.
END_REPORT

exit;
