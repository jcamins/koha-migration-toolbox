#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
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
use C4::Context;
use C4::Items;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $csv = Text::CSV_XS->new({binary => 1, sep_char => "\|"} );
$csv->column_names(qw /catkey barcode itype loc curloc cat1 cat2 homebr seen issues access price scheme call ignore ignore/);
open my $input_file,'<',$input_filename;
LINE:
while (my $line=$csv->getline_hr($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   next LINE if $line->{cat2} ne "ADULT";
   my $new_loc = $NULL_STRING;
   if ($line->{itype} eq "CD-AUDIO" && $line->{cat1} eq "CD-AUDIO") {
      $new_loc = "AUDIOBK";
   }
   if ($line->{itype} eq "BOOK-PBK") {
      if ($line->{cat1} eq "ROMANCE") {
         $new_loc = "PBK-ROM";
      }
      if ($line->{cat1} eq "WESTERN") {
         $new_loc = "PBK-WEST";
      }
   }
   if ($line->{itype} eq "BOOK") {
      if ($line->{cat1} eq "FICTION") {
         $new_loc = "ADFIC";
      }
      if ($line->{cat1} eq "NON-FICTION") {
         $new_loc = "ANF";
      }
      if ($line->{cat1} eq "SCI-FI") {
         $new_loc = "SCI-FI";
      }
      if ($line->{cat1} eq "MYSTERY") {
         $new_loc = "MYSTERY";
      }
      if ($line->{cat1} eq "WESTERN") {
         $new_loc = "WESTERN";
      }
      if ($line->{cat1} eq "ROMANCE") {
         $new_loc = "ROMANCE";
      }
   }
   next LINE if $new_loc eq $NULL_STRING;
   my $item = GetItem(undef, $line->{barcode});
   if (!$item->{location}) {
      $item->{location} = "ONSHELF";
   }
   next LINE if $item->{location} ne "ONSHELF";
   $debug and print "Item $item->{itemnumber} ($line->{barcode}) was $item->{location} will be $new_loc.\n";
   if ($doo_eet) {
      ModItem({ location => $new_loc },undef,$item->{itemnumber});
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
