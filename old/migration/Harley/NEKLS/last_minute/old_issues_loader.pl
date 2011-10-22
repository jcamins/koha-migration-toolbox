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
my $add_sth = $dbh->prepare("INSERT INTO old_issues 
                 (borrowernumber, itemnumber, date_due, branchcode,returndate,lastreneweddate,renewals,timestamp,issuedate) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)");
my $upd_sth = $dbh->prepare("DELETE FROM issues WHERE borrowernumber=? AND itemnumber=?");

my $headerline = $csv->getline($in);
my @fields = @$headerline;

while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $debug and last if ($j>0 && $k>0);
   $debug and print Dumper(@data);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   $add_sth->execute($data[0],$data[1],$data[2],$data[3],$data[5],$data[6],$data[8],$data[9],$data[10]);
   $upd_sth->execute($data[0],$data[1]);
   $j++;
   C4::Items::ModItem({itemlost         => 0,
                       datelastseen     => $data[5],
                       onloan           => undef,
                      },undef,$data[1]);
}

close $in;

print "\n\n$i lines read.\n$j old_issues loaded.\n";
exit;

