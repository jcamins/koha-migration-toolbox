#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use warnings;
use Getopt::Long;
use Text::CSV;
use C4::Context;

my $infile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
);

if (($infile_name eq '')){
    print << 'ENDUSAGE';

Usage:   --in=<infile> --table=<kohatable>

<infile>     A pipe-formatted data file, with header row containing fieldnames.
ENDUSAGE
exit;
}

my $csv=Text::CSV->new();
my $dbh=C4::Context->dbh();
my $i=0;
my $ok=0;
open INFL,"<$infile_name";
my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
my $convertq2 = $dbh->prepare("SELECT itemnumber,timestamp FROM items WHERE barcode = ?");
my $sth = $dbh->prepare("INSERT INTO issues (issuingbranch,branchcode,borrowernumber,itemnumber,date_due,issuedate) VALUES ('DE','DE',?,?,?,?)");
my $headerrow = $csv->getline(INFL);
my @fields=@$headerrow;
while (my $row=$csv->getline(INFL)){
   my @data=@$row;
   $i++;
#   print ".";
#   print "\r$i" unless ($i % 100);
   my ($borrower,$item,$due,$issue,$thistime);
   for (my $j=0;$j<scalar(@data);$j++){
      if ($fields[$j] eq "PTBC"){
         $convertq->execute($data[$j]);
         my $arr= $convertq->fetchrow_hashref();
         $borrower= $arr->{'borrowernumber'};
      }
      if ($fields[$j] eq "ITEMBARCODE"){
         $convertq2->execute($data[$j]);
         my $arr= $convertq2->fetchrow_hashref();
         $thistime = $arr->{'timestamp'};
         $item= $arr->{'itemnumber'};
      }
      if ($fields[$j] eq "DUE"){
         my ($mon,$day,$year) = split (/\//,substr($data[$j],0,10));
         $due = sprintf "%4d-%02d-%02d",$year,$mon,$day;
      }
      if ($fields[$j] eq "OUTDATE"){
         my ($mon,$day,$year) = split (/\//,substr($data[$j],0,10));
         $issue = sprintf "%4d-%02d-%02d",$year,$mon,$day;
      }
   }
   if ($thistime gt "2010-12-30 21:00"){
      print "FOUND!  $borrower, $item, $due, $issue, $thistime\n";
      $sth->execute($borrower,$item,$due,$issue);
      $ok++;
   }
}
close INFL; 
print "$ok found\n";
