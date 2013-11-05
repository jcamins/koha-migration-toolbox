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
#      <borrower barcode>,<new value>[,<new value>...]
#   -which values are to be changed (comma separated list)
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
my $field_to_change = q{};

GetOptions(
   'in:s'     => \$infile_name,
   'field:s'  => \$field_to_change,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if (($infile_name eq q{}) || ($field_to_change eq q{})){
   print "Something's missing.\n";
   exit;
}

my $written=0;
my $borrower_not_found=0;
my @fields=split /,/,$field_to_change;
my $csv=Text::CSV_XS->new({ binary => 1});
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
open my $infl,"<",$infile_name;

RECORD:
while (my $line=$csv->getline($infl)){
   last RECORD if ($debug and $i>5000); 
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line; 
   $sth->execute($data[0]);
   my $rec=$sth->fetchrow_hashref();

   if (!$rec){
      print "NO BORROWER: $data[0]\n";
      $borrower_not_found++;
      next RECORD;
   }
FIELD:
   for my $j (0..scalar(@fields)-1) {
      next FIELD if $data[$j+1] eq '';
      $debug and print "$data[0] ($rec->{borrowernumber})  $fields[$j] => $data[$j+1]\n";
      if ($doo_eet){
         my $update_sth =$dbh->prepare("UPDATE borrowers SET $fields[$j]=\"$data[$j+1]\" WHERE borrowernumber = $rec->{'borrowernumber'}");
         $update_sth->execute();
        # C4::Members::ModMember(borrowernumber   => $rec->{'borrowernumber'},
        #                        $fields[$j] => $data[$j+1],
        #                       );

      }
   }
   $written++;
}

print "\n\n$i records read.\n$written borrowers updated.\n$borrower_not_found not updated due to unknown barcode.\n";
