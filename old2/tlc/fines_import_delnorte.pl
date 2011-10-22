#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# This script loads files of fines from VTLS Virtua
#
# -D Ruth Bavousett
#
#---------------------------------

use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Accounts;

my $infile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
);

if (($infile_name eq '')){
    print << 'ENDUSAGE';

Usage:  fines_import --in=<infile> 

<infile>     A pipe-formatted data file, with header row containing fieldnames.

ENDUSAGE
exit;
}

my $dbh= C4::Context::dbh();

my $sth2=$dbh->prepare("INSERT INTO accountlines
                       (borrowernumber,itemnumber,date,amount,description,accounttype,amountoutstanding,lastincrement,accountno)
                        VALUES (?,?,?,?,?,?,?,?,?)");

my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
my $convertq2 = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode = ?");

open INFL,"<$infile_name";
my $csv=Text::CSV->new();
my $i=0;
my $head=$csv->getline(INFL);
my @fields=@$head;
while (my $row=$csv->getline(INFL)){
   my @data=@$row;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my ($borr,$item,$date,$amt,$desc,$accttyp,$outst,$lastinc,$paycomm);
   for (my $j=0;$j<scalar(@data);$j++){
      if ($fields[$j] eq "BARCODE"){
         $convertq->execute($data[$j]);
         my $arr= $convertq->fetchrow_hashref();
         $borr= $arr->{'borrowernumber'};
      }
      if ($fields[$j] eq "ITEMBARCODE"){
       if ($data[$j]){
         $convertq2->execute($data[$j]);
         my $arr= $convertq2->fetchrow_hashref();
         $item= $arr->{'itemnumber'};
       }
       else {$item = undef;}
      }
      if ($fields[$j] eq "POSTDATE"){
         my ($mon,$day,$year) = split (/\//,substr($data[$j],0,10));
         $date = sprintf "%4d-%02d-%02d",$year,$mon,$day;
      }
      if ($fields[$j] eq "DUEAMOUNT"){
         $amt = $data[$j];
         $outst = $data[$j];
         $lastinc = $data[$j];
      }
      if ($fields[$j] eq "DESCRIPTION"){
         $desc = $data[$j];
      }
      if ($fields[$j] eq "PAYMENTTYPE"){
         $accttyp = "M";
         $accttyp = "L" if ($data[$j] eq "L");
         $accttyp = "F" if ($data[$j] eq "OV");
      }
    }
    my $nextaccntno = C4::Accounts::getnextacctno($borr);
    $desc .= $paycomm if ($paycomm);
    $sth2->execute($borr,$item,$date,$amt,$desc,$accttyp,$outst,$lastinc,$nextaccntno);
}

