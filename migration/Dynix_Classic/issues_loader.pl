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
#   -nothing
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -nothing

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use Date::Calc qw(Add_Delta_Days);
use C4::Context;
use C4::Items;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename      = $NULL_STRING;
my $branch_map_filename = $NULL_STRING;
my $default_branch      = 'UNKNOWN';
my $borrower_map_filename = $NULL_STRING;
my %branch_map;
my %borrower_map;

GetOptions(
    'in=s'               => \$input_filename,
    'branch_map=s'       => \$branch_map_filename,
    'borrower_map=s'     => \$borrower_map_filename,
    'default_branch=s'   => \$default_branch,
    'debug'              => \$debug,
    'update'             => \$doo_eet,
);

for my $var ($input_filename, $default_branch,$borrower_map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

Readonly my $FIELD_SEP    => chr(254);
my $dbh = C4::Context->dbh();
my $insert_sth = $dbh->prepare("INSERT INTO issues 
                                (borrowernumber, itemnumber, date_due, issuedate, branchcode) 
                                VALUES (?, ?, ?, ?, ?)");

if ($branch_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$branch_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $map_file;
}

if ($borrower_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$borrower_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      if ($data[0] ne $NULL_STRING) {
         $borrower_map{$data[0]} = $data[1];
      }
   }
   close $map_file;
}

open my $input_file,'<',$input_filename;
RECORD:
while (my $line = readline($input_file)){
   last RECORD if ($debug and $i>10);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   #$debug and print "\n$i: ";
   
   chomp $line;
   $line =~ s///g;
   my @columns = split /$FIELD_SEP/,$line;
 
   my $barcode = $columns[0];
   my $item = GetItemnumberFromBarcode($barcode);
   my $patron = $borrower_map{$columns[1]};
   if (!$item ) {
      print "Item $barcode not found.\n";
      $problem++;
      next RECORD; 
   }
   if (!$patron){ 
      print "Patron $columns[1] not found.\n";
      $problem++;
      next RECORD;
   }

   my $date_due = _process_date($columns[2]);
   my $date_out = _process_date($columns[4]);
   my $branch = $columns[9];

   if (exists $branch_map{$branch} ) {
      $branch = $branch_map{$branch};
   }

   $debug and print "PATRON: $patron ITEM: $item  OUT: $date_out DUE: $date_due  BRANCH: $branch\n";
   if ($doo_eet) {
      $insert_sth->execute($patron,$item,$date_due,$date_out,$branch);
   }

   $written++;
}
close $input_file;

print "\n\n$i lines read.\n$written borrowers written.\n$problem problem records not loaded..\n";

exit;

sub _process_date {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq q{};
   return undef if $datein < 0;
   my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$datein);
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
