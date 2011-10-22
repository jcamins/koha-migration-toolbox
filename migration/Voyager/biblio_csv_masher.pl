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
#   -input CSV from SQL extract of MARC records
#
# DOES:
#   -nothing
#
# CREATES:
#   -output MARC
#
# REPORTS:
#   -count of lines read
#   -count of MARC records created

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

my $input_filename  = $NULL_STRING;
my $output_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'out=s'    => \$output_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}
my $csv = Text::CSV_XS->new({binary=>1});

my $raw_marc      = $NULL_STRING;

open my $input_file, '<:utf8',$input_filename;
my $dummy = readline($input_file);  #toss the header line!
open my $output_file,'>:utf8',$output_filename;
LINE:
while (my $line=$csv->getline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;

   if ($data[2] == 1) {
      write_record($raw_marc);
      $written++;
      $raw_marc      = $data[0];
      next LINE;
   }
   else {
      $raw_marc .= $data[0]; 
   }
}
write_record($raw_marc);   # process the last record!

close $input_file;
close $output_file;

print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

exit;

sub write_record {
   my $marc = shift;
   if ($marc ne $NULL_STRING) {
      print {$output_file} $marc;
   }
   return;
}
