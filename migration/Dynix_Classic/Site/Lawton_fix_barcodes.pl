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

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use C4::Context

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $barcode_filename    = $NULL_STRING;
my $output_filename     = $NULL_STRING;

my %city_map;
my %state_map;
my %branch_map;
my %category_map;

GetOptions(
    'out=s'              => \$output_filename,
    'barcode=s'          => \$barcode_filename,
    'debug'              => \$debug,
);

for my $var ($output_filename,$barcode_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %barcode_hash;

Readonly my $CSV_SEP      => '\|';
Readonly my $FIELD_SEP    => chr(254);
Readonly my $SUBFIELD_SEP => chr(253);

if ($barcode_filename){
   open my $barcode_file,'<',$barcode_filename;
   while (my $line = readline($barcode_file)){
      my @columns=split /$FIELD_SEP/,$line;
      $barcode_hash{$columns[1]} = $columns[0];
   }
   close $barcode_file;
}

my $no_barcode = 0;

my $dbh=C4::Context->dbh();
my $sth = $dbh->prepare("SELECT cardnumber,sort1 FROM borrowers WHERE cardnumber LIKE 'TEMP%'");
$sth->execute();
open my $output_file,'>:utf8',$output_filename;

RECORD:
while (my $borrower = $sth->fetchrow_hashref()){
   last RECORD if ($debug and $i>10);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   if (!exists $barcode_hash{$borrower->{sort1} }) {
      $no_barcode++;
      next RECORD;
   }
   print {$output_file} "$borrower->{cardnumber},$barcode_hash{$borrower->{sort1}}\n";
   $written++;
}
close $output_file;

print "\n\n$i lines read.\n$written borrowers written.\n$no_barcode with no barcode.\n";

exit;
