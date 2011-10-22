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
my $add_sth = $dbh->prepare("INSERT INTO accountlines
          (borrowernumber,accountno,itemnumber,date,amount,description,accounttype,amountoutstanding,timestamp,notify_id,notify_level,lastincrement)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ");
my $add_sth_2 = $dbh->prepare("INSERT INTO accountlines
          (borrowernumber,accountno,date,amount,description,accounttype,amountoutstanding,timestamp,notify_id,notify_level,lastincrement)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ");
my $upd_sth = $dbh->prepare("UPDATE accountlines
        SET itemnumber=?,date=?,amount=?,description=?,accounttype=?,amountoutstanding=?,timestamp=?,notify_id=?,notify_level=?,lastincrement=?
        WHERE borrowernumber=? AND accountno=?");
my $upd_sth_2 = $dbh->prepare("UPDATE accountlines
        SET date=?,amount=?,description=?,accounttype=?,amountoutstanding=?,timestamp=?,notify_id=?,notify_level=?,lastincrement=?
        WHERE borrowernumber=? AND accountno=?");
my $find_sth = $dbh->prepare("SELECT * FROM accountlines WHERE borrowernumber = ? and accountno = ?");

my $headerline = $csv->getline($in);
my @fields = @$headerline;

while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $debug and last if ($j>0 && $k>0);
   $debug and print Dumper(@data);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   $find_sth->execute($data[0],$data[1]);
   if ($find_sth->rows){
      if ($data[2]){
         $upd_sth->execute($data[2],$data[3],$data[4],$data[5],$data[7],$data[8],$data[9],$data[10],$data[11],$data[12],$data[0],$data[1]);
      }
      else {
         $upd_sth_2->execute($data[3],$data[4],$data[5],$data[7],$data[8],$data[9],$data[10],$data[11],$data[12],$data[0],$data[1]);
      }
      $k++;
   }
   else{
      if ($data[2]){
         $add_sth->execute($data[0],$data[1],$data[2],$data[3],$data[4],$data[5],$data[7],$data[8],$data[9],$data[10],$data[11],$data[12]);
      }
      else {
         $add_sth_2->execute($data[0],$data[1],$data[3],$data[4],$data[5],$data[7],$data[8],$data[9],$data[10],$data[11],$data[12]);
      }
      $j++;
   }
}

close $in;

print "\n\n$i lines read.\n$j fines loaded.\n$k finees updated.\n";
exit;

