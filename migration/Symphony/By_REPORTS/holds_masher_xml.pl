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
#   -input XML from Symphony
#
# DOES:
#   -nothing
#
# CREATES:
#   -output CSV
#
# REPORTS:
#   -count of holds read
#   -count of lines written

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use XML::Simple;

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

my $input_filename  = $NULL_STRING;
my $output_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'out=s'    => \$output_filename,
    'debug'    => \$debug,
);

for my $var ($input_filename,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $xml = XMLin($input_filename);

open my $output_file,'>',$output_filename;
print {$output_file} "borrowerbar,itembar,reservedate,branchcode,constrainttype\n";

RECORD:
foreach my $hold (@{$xml->{hold}}) {
   last RECORD if ($debug && $i>1);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print Dumper($hold);
   my $borrower = $hold->{user}->{userID};
   my $item     = $hold->{catalog}->{call}->{item}->{itemID};
   my $date     = substr($hold->{datePlaced},0,10);
   my $branch   = $hold->{pickupLibrary};
   print {$output_file} "$borrower,$item,$date,$branch,a\n";
   $written++;
}

print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
