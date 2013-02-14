#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#  modifed by J.Nelson for virtualshelfcontents.owner updates
#---------------------------------
#
# EXPECTS:
#   -input CSV in this form:
#      <listnumber>,<borrowernumber>
#
# DOES:
#   -updates the values described, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of lists modified
#   -details of what will be changed, if --debug is set

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;

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

if ( $infile_name eq q{} ) {
   print "Something's missing.\n";
   exit;
}

my $written=0;

my $csv=Text::CSV_XS->new({ binary => 1});
my $dbh=C4::Context->dbh();
open my $infl,"<",$infile_name;

RECORD:
while (my $line=$csv->getline($infl)){
   last RECORD if ($debug and $i>5000); 
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line; 

   $debug and print "listnumber $data[0] owner: $data[1]\n";
      if ($doo_eet){
         my $update_sth =$dbh->prepare("UPDATE virtualshelfcontents SET borrowernumber = ? WHERE shelfnumber= ?");
         $update_sth->execute($data[1], $data[0]);
      }
   $written++;
}

print "\n\n$i records read.\n$written lists updated.\n";
