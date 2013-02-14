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
#   -flat exports of MARC_BIB and BIB tables from Dynix Classic
#
# DOES:
#   -nothing
#
# CREATES:
#   -output file of USMARC records
#
# REPORTS:
#   -problem records
#   -count of records examined
#   -count of records written
#   -count of problems

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

my $input_filename   = $NULL_STRING;
my $input_2_filename = $NULL_STRING;
my $output_filename  = $NULL_STRING;
my $use_hash         = 1;

GetOptions(
    'in=s'     => \$input_filename,
    'bib=s'    => \$input_2_filename,
    'out=s'    => \$output_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$input_2_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

Readonly my $field_sep    => chr(254);
Readonly my $tag_sep      => chr(253);
Readonly my $subfield_sep => chr(252);

my %subrecord_hash;
if ($use_hash){
   print "Loading subrecord data into memory.\n";
   open my $subrecord_file,'<',$input_2_filename;
   while (my $line = readline($subrecord_file)) {
      $i++;
      print '.'    unless ($i % 10);
      print "\r$i" unless ($i % 100);
      chomp $line;
      $line =~ s/$//;
      my ($record_number,$rest) = split /$field_sep/,$line;
      $subrecord_hash{$record_number} = $line;
   }
   close $subrecord_file;
}
print "\n$i lines processed.\n\n";
$i=0;
my %data_matrix;

open my $input_file, '<',     $input_filename;
#open my $output_file,'>:utf8',$output_filename;
LINE:
while (my $line=readline($input_file)) {
   last LINE if ($debug && $i >5);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   chomp $line;
   $line =~ s/$//;
   my @columns = split /$field_sep/, $line;

   my $record_number = $columns[0];

   my @matches;
   if ($use_hash){
      $matches[0] = $subrecord_hash{$record_number};
   }
   else{
      @matches = qx{grep "^$record_number" $input_2_filename};
   }

   if (scalar(@matches) == 0) {
      print "\nProblem: record $record_number; no secondary data present\n";
      $problem++;
      next LINE;
   }

   my @subcolumns;

MATCH:
   foreach my $match (@matches) {
      chomp $match;
      $match =~ s/$//;
      @subcolumns = split /$field_sep/, $match;
      last MATCH if $subcolumns[0] eq $record_number;
   }

   my $tag_counter=2;
TAGFIELD:
   foreach my $tag (split /$tag_sep/, $columns[2]) {
      $tag_counter++;
      if ($tag eq $NULL_STRING) {
         $tag_counter--;
         next TAGFIELD;
      }
      my $tagstr = sprintf "%03d",$tag;
      if ($tag < 10) {
         next TAGFIELD;
      }
      my $ind1=substr($columns[$tag_counter],0,1);
      my $ind2=substr($columns[$tag_counter],1,1);
      my @subfields = split /$subfield_sep/,$columns[$tag_counter];
SUBFIELD:
      foreach my $j (1..scalar(@subfields)-1) {
         my $subtag = substr($subfields[$j],0,1);
         my $data   = substr($subfields[$j],1);
         if ($subtag eq '$') {
            $subtag = substr($subfields[$j],1,1);
            $data   = substr($subfields[$j],2);
         }
         next SUBFIELD if $subtag eq '@';
         if ($data =~ /(\d+)\.(\d+)\.\.(\d+)\.(\d+)/) {
            my $fieldnum = $1;
            my $tagg_to_count = sprintf "%03d-%s%s", $fieldnum,$tagstr,$subtag;
            $data_matrix{$tagg_to_count}++; 
         }
      }
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

for my $kee (sort keys %data_matrix) {
   print "$kee:  $data_matrix{$kee}\n";
}

exit;
