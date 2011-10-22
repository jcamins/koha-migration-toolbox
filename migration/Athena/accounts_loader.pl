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
use C4::Accounts;
$|=1;
my $debug=0;
my $doo_eet=0;

my $infile_name = "";
my $branch = "";

GetOptions(
    'in=s'            => \$infile_name,
    'branch=s'        => \$branch,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '') || ($branch eq "")){
  print "Something's missing.\n";
  exit;
}

my $csv = Text::CSV->new();
open my $in,"<$infile_name";
my $i=0;
my %problem;
my %success;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO accountlines (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding, itemnumber)
        VALUES (?, ?, ?, ?,?, ?,?,?)");
my $sth_noitem = $dbh->prepare("INSERT INTO accountlines (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding)
        VALUES (?, ?, ?, ?, ?,?,?)
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $dum = $csv->getline($in);

MAINLOOP:
while (my $line = $csv->getline($in)){
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   $borr_sth->execute($data[0]);
   my $db_borr_fetch=$borr_sth->fetchrow_hashref();
   my $borrnum=$db_borr_fetch->{'borrowernumber'};
   if (!borrnum){
      $problem{'borrowers not found'}++;
      next MAINLOOP;
   }
   $item_sth->execute($data[2]);
   my $db_item_fetch=$item_sth->fetchrow_hashref();
   my $itemnum = $db_item_fetch->{'itemnumber'};
   my $transdate = _process_date($data[4]);
   my $transdesc = "Migration: ".$data[3];
   my $accountno  = getnextacctno($borrowernumber);
   my $amount = $data[9];
   if ($amount > 0){
      if ($itemnum){
         $doo_eet and $sth->execute($borrnum,$accountno,$transdate,$amount,$transdesc,"M",$amount,$itemnum);
         $success{'fines inserted with item number present"}++;
      }
      else{
         $doo_eet and $sth->execute($borrnum,$accountno,$transdate,$amount,$transdesc,"M",$amount);
         $success{'fines inserted with item number not present"}++;
      }
   }
   else{
      if ($transdesc =~ /Payment/){
      }
      else{
         if ($itemnum){
            $doo_eet and $sth->execute($borrnum,$accountno,$transdate,$amount,$transdesc,"FOR",$amount,$itemnum);
            $success{'fines forgiven with item number present"}++;
         }
         else{
            $doo_eet and $sth->execute($borrnum,$accountno,$transdate,$amount,$transdesc,"FOR",$amount);
            $success{'fines forgiven with item number not present"}++;
         }
      }
   }
}
close $in;

print "\n\n$i lines read.\n";
foreach my $kee (sort keys %success){
   print "$success{$kee} $kee\n";
}
print "\nProblems:\n";
foreach my $kee (sort keys %problem){
   print "$problem{$kee} $kee\n";
}
   
exit;

sub _process_date {
   my $datein= shift;
   return "" if ($datein eq "");
   my ($month,$day,$year) = split(/\//,$datein);
   if ($year <=40){
      $year += 2000;
   }
   else {
      $year += 1900;
   }
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
