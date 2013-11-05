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
#   -a file of biblionumbers, one per line.
#
# DOES:
#   -deletes the bibs, if there are no items attached, and --update is given
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -record numbers, if --debug is given.
#   -counts of results.

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
use C4::Biblio;

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
    'in=s'        => \$input_filename,
    'debug'       => \$debug,
    'update'      => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $csv=Text::CSV_XS->new();
open my $input_file,'<',$input_filename;
LINE:
while (my $line=$csv->getline($input_file)){
   last if ($debug and $i>0);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;   
   my $err;

   $debug and print "Biblio:  $data[0]\n";
   if ($doo_eet){
      $err = C4::Biblio::DelBiblio($data[0]);
   }
   if ($err) {
      print "Problem deleting biblio $data[0].\n";
      $problem++;
      next LINE;
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

