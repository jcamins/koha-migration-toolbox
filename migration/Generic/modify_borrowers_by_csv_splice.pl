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
#      <borrower barcode>,<new value>
#   -which value is to be changed
#
# DOES:
#   -updates the value described, if --update is set
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
my $mapfile_name = q{};
my $field_to_change = q{};
my $append=0;

GetOptions(
   'in:s'     => \$infile_name,
   'map:s'    => \$mapfile_name,
   'field:s'  => \$field_to_change,
   'append'   => \$append,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if (($infile_name eq q{}) || ($field_to_change eq q{})){
   print "Something's missing.\n";
   exit;
}

my %barcode_map;
my $csv=Text::CSV_XS->new();
if ($mapfile_name ne q{}) {
   open my $mapfile,'<',$mapfile_name;
   while (my $line=$csv->getline($mapfile)) {
      my @data = @$line;
      $barcode_map{$data[0]} = $data[1];
   }
}

my $written=0;
my $borrower_not_found=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT borrowernumber,$field_to_change FROM borrowers WHERE cardnumber = ?");
open my $infl,"<",$infile_name;

RECORD:
while (my $line=$csv->getline($infl)){
   last RECORD if ($debug and $written>10);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line; 
   next RECORD if $data[1] eq '';
   if (exists $barcode_map{$data[0]}) {
      $data[0] = $barcode_map{$data[0]};
   }
   $sth->execute($data[0]);
   my $rec=$sth->fetchrow_hashref();

   if (!$rec){
      $borrower_not_found++;
      $debug and print "not found $data[0]\n";
      next RECORD;
   }

   my $val = $rec->{$field_to_change} || "";
   if ($append) {
     $val .= " " . $data[1];
   }
   else {
     $val = $data[1];
   }

   next RECORD if ($rec->{$field_to_change} eq $val);

   $debug and print "$data[0] ($rec->{borrowernumber}) old $rec->{$field_to_change}  $field_to_change => $val\n";

   if ($doo_eet){
      C4::Members::ModMember(borrowernumber   => $rec->{'borrowernumber'},
                             $field_to_change => $val,
                            );

   }
   $written++;
}

print "\n\n$i records read.\n$written borrowers updated.\n$borrower_not_found not updated due to unknown barcode.\n";
