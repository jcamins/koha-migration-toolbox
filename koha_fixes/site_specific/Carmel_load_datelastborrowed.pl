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
#   -input CSV in this form:
#      <item barcode>,<new value>
#
# DOES:
#   -updates the value described, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of items modified
#   -count of items not modified due to missing barcode
#   -details of what will be changed, if --debug is set

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Items;
$|=1;
my $debug = 0;
my $doo_eet = 0;
my $i=0;

my $infile_name = q{};
my $field_to_change = 'datelastborrowed';

GetOptions(
   'in:s'     => \$infile_name,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if (($infile_name eq q{})){
   print "Something's missing.\n";
   exit;
}

my $written=0;
my $item_not_found=0;
my $csv=Text::CSV_XS->new();
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,datelastborrowed FROM items WHERE barcode = ?");
open my $infl,"<",$infile_name;

RECORD:
while (my $line=$csv->getline($infl)){
   last RECORD if ($debug and $i>10);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line; 
   $sth->execute($data[0]);
   my $rec=$sth->fetchrow_hashref();

   if (!$rec){
      $item_not_found++;
      next RECORD;
   }

   $debug and print "$data[0] ($rec->{itemnumber})  $field_to_change => $data[1]\n";

   next RECORD if $rec->{'datelastborrowed'};

   if ($doo_eet){
      C4::Items::ModItem({ $field_to_change => $data[1] },undef,$rec->{'itemnumber'});
   }
   $written++;
}

print "\n\n$i records read.\n$written items updated.\n$item_not_found not updated due to unknown barcode.\n";
