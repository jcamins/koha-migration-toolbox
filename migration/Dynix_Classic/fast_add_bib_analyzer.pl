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

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use MARC::Record;
use MARC::Field;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename    = $NULL_STRING;
my $bib_data_filename = $NULL_STRING;


GetOptions(
    'in=s'     => \$input_filename,
    'bib=s'    => \$bib_data_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$bib_data_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

Readonly my $FIELD_SEP    => chr(254);
Readonly my $TAG_SEP      => chr(253);
my @subfields_possible = qw/a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9/;

my %subrecord_hash;
print "Loading subrecord data into memory.\n";
open my $subrecord_file,'<',$bib_data_filename;
while (my $line = readline($subrecord_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s/^M$//;
   my ($record_number,$rest) = split /$FIELD_SEP/,$line;
   $subrecord_hash{$record_number} = $line;
}
close $subrecord_file;

$i = 0;
my %columns_in_use;

open my $input_file,'<:utf8',$input_filename;
LINE:
while (my $line=readline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s///g; 
   my @columns = split /$FIELD_SEP/,$line;
   if (!exists $subrecord_hash{$columns[1]}) {
      $problem++;
      next LINE;
   }

   my $keep_itype;
   my $keep_issues = 0;
   my $title_line = $subrecord_hash{$columns[1]};
   $title_line =~ s///g;
   my @title_columns = split /$FIELD_SEP/, $title_line;

   for my $j (0..scalar(@title_columns)-1) {
      if ($title_columns[$j] ne $NULL_STRING) {
         $columns_in_use{$j}++;
         if ($j==33) {
            print $title_columns[13]."\n";
         }
      }
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$problem records not loaded due to problems.
END_REPORT

print "\nColumns used:\n";
foreach my $kee (sort keys %columns_in_use){
   print $kee.":   ".$columns_in_use{$kee}."\n";
}
print "\n";

exit;
