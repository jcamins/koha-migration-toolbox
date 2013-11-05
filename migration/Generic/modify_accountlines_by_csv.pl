#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#  -modified by:
#    J Nelson, took borrower modification script and change to modify accountlines.amountoutstanding 5/25/2012
#
#---------------------------------
#
# EXPECTS:
#   -input CSV in this form:
#      <borrowernumber>
#
# DOES:
#   -updates the values described, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of borrowers modified

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Members;
$|=1;
my $debug = 0;
my $doo_eet = 0;
my $i=0;

my $infile_name = q{};
#my $field_to_change = q{};

GetOptions(
   'in:s'     => \$infile_name,
#   'field:s'  => \$field_to_change,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if ($infile_name eq q{}) {
   print "Something's missing.\n";
   exit;
}

my $csv=Text::CSV_XS->new();
my $dbh=C4::Context->dbh();
open my $infl,"<",$infile_name;

RECORD:
while (my $line=$csv->getline($infl)){
   last RECORD if ($debug and $i>5000); 
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line; 

      if ($doo_eet){
         my $update_sth =$dbh->prepare("UPDATE accountlines SET amountoutstanding=0 WHERE borrowernumber = $data[0]");
         $update_sth->execute();
      }
}

print "\n\n$i records read.\n$written borrowers updated.\n";
