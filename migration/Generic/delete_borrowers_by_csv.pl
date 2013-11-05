#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# modifed by Joy Nelson to create a delete borrowers version
#---------------------------------
#
# EXPECTS:
#   -input CSV in this form:
#      <borrowernumber>
#
# DOES:
#   -deletes from borrowers if update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of borrowers modified
#   -count of borrowers not modified due to missing barcode
#   -details of what will be changed, if --debug is set

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

GetOptions(
   'in:s'     => \$infile_name,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if ($infile_name eq q{}){
   print "Something's missing.\n";
   exit;
}

my $written=0;
my $csv=Text::CSV_XS->new();
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("delete FROM borrowers WHERE borrowernumber = ?");
my $fine_sth=$dbh->prepare("delete from accountlines where borrowernumber = ?");
open my $infl,"<",$infile_name;

RECORD:
while (my $line=$csv->getline($infl)){
   last RECORD if ($debug and $written>10);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line; 
  if ($doo_eet) {
   $fine_sth->execute($data[0]);
   $sth->execute($data[0]);
   $written++;
  }
}

print "\n\n$i records read.\n$written borrowers deleted.\n";
