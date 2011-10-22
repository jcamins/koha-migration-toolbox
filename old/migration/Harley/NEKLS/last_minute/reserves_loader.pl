#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;

my $infile_name = "";
my $branch = "";

GetOptions(
    'in=s'            => \$infile_name,
    'debug'           => \$debug,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $csv = Text::CSV->new();
open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $k=0;
my $dbh = C4::Context->dbh();
my $add_sth = $dbh->prepare("INSERT INTO reserves 
                 (borrowernumber, reservedate,biblionumber,constrainttype,branchcode,priority, found,timestamp, waitingdate,expirationdate) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
my $add_sth_2 = $dbh->prepare("INSERT INTO reserves 
                 (borrowernumber, reservedate,biblionumber,constrainttype,branchcode,priority, found,timestamp,itemnumber, waitingdate,expirationdate) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
my $upd_sth = $dbh->prepare("UPDATE reserves 
        SET reservedate=?, constrainttype=?, branchcode=?, priority=?, found=?, timestamp=?, waitingdate=?, expirationdate=? 
        WHERE borrowernumber=? AND biblionumber=?");
my $upd_sth_2 = $dbh->prepare("UPDATE reserves 
        SET reservedate=?, constrainttype=?, branchcode=?, priority=?, found=?, timestamp=?, itemnumber=?, waitingdate=?, expirationdate=? 
        WHERE borrowernumber=? AND biblionumber=?");
my $find_sth = $dbh->prepare("SELECT * FROM reserves WHERE borrowernumber = ? and biblionumber = ?");

my $headerline = $csv->getline($in);
my @fields = @$headerline;

while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $debug and last if ($i>0);
   $debug and print Dumper(@data);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   $find_sth->execute($data[1],$data[3]);
   if ($find_sth->rows){
      if ($data[13]){
         $upd_sth_2->execute($data[2],$data[4],$data[5],$data[10],$data[11],$data[12],$data[13],$data[14],$data[15],$data[1],$data[3]);
      }
      else {
         $upd_sth->execute($data[2],$data[4],$data[5],$data[10],$data[11],$data[12],$data[14],$data[15],$data[1],$data[3]);
      }

      $k++;
   }
   else{
      if ($data[13]){
         $add_sth_2->execute($data[1],$data[2],$data[3],$data[4],$data[5],$data[10],$data[11],$data[12],$data[13],$data[14],$data[15]);
      }
      else {
         $add_sth->execute($data[1],$data[2],$data[3],$data[4],$data[5],$data[10],$data[11],$data[12],$data[14],$data[15]);
      }
      $j++;
   }
}

close $in;

print "\n\n$i lines read.\n$j reserve loaded.\n$k reserves updated.\n";
exit;

