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
my $add_sth = $dbh->prepare("INSERT INTO branchtransfers 
                 (itemnumber,datesent,frombranch,datearrived,tobranch,comments)
                  VALUES (?, ?, ?, ?, ?, ?) ");
my $upd_sth = $dbh->prepare("UPDATE branchtransfers
        SET frombranch=?, datearrived=?, tobranch=?,comments=?
        WHERE itemnumber=? AND datesent=?");
my $find_sth = $dbh->prepare("SELECT * FROM branchtransfers WHERE itemnumber = ? and datesent = ?");

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
      $upd_sth->execute($data[2],$data[3],$data[4],$data[5],$data[0],$data[1]);
      $k++;
   }
   else{
      $add_sth->execute($data[0],$data[1],$data[2],$data[3],$data[4],$data[5]);
      $j++;
   }
   my $lastdate;
   my $lastbranch;
   if ($data[3]){
      $lastdate=$data[3];
      $lastbranch=$data[4];
   }
   else {
      $lastdate=$data[1];
      $lastbranch=$data[2];
   }
   C4::Items::ModItem({datelastseen     => $lastdate,
                       holdingbranch    => $lastbranch,
                      },undef,$data[0]);
}

close $in;

print "\n\n$i lines read.\n$j issues loaded.\n$k issues updated.\n";
exit;

