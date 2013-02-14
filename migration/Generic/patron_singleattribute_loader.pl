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
#   -input file CSV in this form:
#       <patron_barcode>,<attribute_value>
#   -attribute name (code) to load
#
# DOES:
#   -adds patron attribute value, if borrower is defined and --update is specified
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -values it *would* have added, if --debug is specified
#   -count of records read
#   -count of records not loaded because borrower barcode does not exist
#   -count of records loaded 

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Members;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $infile_name = "";
my $attribute_name = "";

GetOptions(
    'in=s'     => \$infile_name,
    'attr=s'   => \$attribute_name,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq q{}) || ($attribute_name eq q{})){
   print "You're missing something.\n";
   exit;
}

my $borrower_not_found=0;
my $written=0;
my $csv=Text::CSV_XS->new();
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("INSERT INTO borrower_attributes (borrowernumber,code,attribute) VALUES (?,?,?)");
my $attr_sth=$dbh->prepare("SELECT borrowernumber from borrower_attributes where borrowernumber=? and code=?");

open my $io,"<$infile_name";
RECORD:
while (my $row=$csv->getline($io)){
   last RECORD if ($debug and $i>10);
   $i++;
   print "." unless ($i %10);
   print "\r$i" unless ($i % 100);
   my @data=@$row;
   my $borrower=GetMemberDetails(undef,$data[0]);
   if (!$borrower->{borrowernumber}){
      $borrower_not_found++;
      next RECORD;
   }

   $attr_sth->execute($borrower->{borrowernumber},$attribute_name);
   my $attr=$attr_sth->fetchrow_hashref();   

   my $data_to_use = uc $data[1];

   if (!$attr) {
      $debug and print "$data[0] ($borrower->{borrowernumber}): $attribute_name:$data_to_use\n";
      if ($doo_eet){
         $sth->execute($borrower->{borrowernumber},$attribute_name,$data_to_use);
      }
      $written++;
   } 

}
close $io;

print "\n\n$i records read.\n$borrower_not_found records not loaded because borrower not found.\n$written records loaded.\n";
