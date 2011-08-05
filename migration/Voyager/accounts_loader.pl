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
my $use_inst_id=0;

GetOptions(
    'in=s'            => \$infile_name,
    'use_inst'        => \$use_inst_id,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '')){
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
        VALUES (?, ?, ?, ?, ?,?,?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $dum = $csv->getline($in);

MAINLOOP:
while (my $line = $csv->getline($in)){
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   my $thisbar = $data[0];
   if ($use_inst_id){
      $thisbar=$data[1];
   }
   if ($thisbar eq q{}){
      $thisbar=printf "TEMP%d",$data[2];
   }
   $borr_sth->execute($thisbar);
   my $db_borr_fetch=$borr_sth->fetchrow_hashref();
   my $borrnum=$db_borr_fetch->{'borrowernumber'};
   if (!$borrnum){
      $problem{'borrowers not found'}++;
      next MAINLOOP;
   }
   $item_sth->execute($data[3]);
   my $db_item_fetch=$item_sth->fetchrow_hashref();
   my $itemnum = $db_item_fetch->{'itemnumber'};
   my $transdate = _process_date($data[5]);
   my $accountno  = getnextacctno($borrnum);
   my $amount = $data[6]/100;

   my $transdesc;
   my $accounttype;
   if ($data[4] == 2){
      $transdesc = "Lost Item Fee - ".$data[7];
      $accounttype = 'L';
   }
   else{
      $transdesc = "Lost Item Processing Fee - ".$data[7];
      $accounttype = 'M';
   }
   if ($itemnum){
      $doo_eet and $sth->execute($borrnum,$accountno,$transdate,$amount,$transdesc,$accounttype,$amount,$itemnum);
      $success{'fines inserted with item number present'}++;
   }
   else{
      $doo_eet and $sth->execute($borrnum,$accountno,$transdate,$amount,$transdesc,$accounttype,$amount);
      $success{'fines inserted with item number not present'}++;
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
   my $datein=shift;
   return undef if $datein eq q{};
   my %months =(
                  JAN => 1, FEB => 2,  MAR => 3,  APR => 4,
                  MAY => 5, JUN => 6,  JUL => 7,  AUG => 8,
                  SEP => 9, OCT => 10, NOV => 11, DEC => 12
               );
   my ($day,$monthstr,$year) = split /\-/, $datein;
   if ($year < 40){
       $year +=2000;
   }
   else{
       $year +=1900;
   }
   return sprintf "%4d-%02d-%02d",$year,$months{$monthstr},$day;
}
