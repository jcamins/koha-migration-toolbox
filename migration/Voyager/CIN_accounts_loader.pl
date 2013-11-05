#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -JEN 4/3/201
#   update for mapping itemid to barcode using map
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Accounts;
use autodie;

$|=1;
my $debug=0;
my $doo_eet=0;

my $infile_name = "";
my $use_inst_id=0;
my $mapfile_name=q{};

GetOptions(
    'in=s'            => \$infile_name,
    'map=s'           => \$mapfile_name,
    'use_inst'        => \$use_inst_id,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}
my $i=0;

my %barcode_map;
if ($mapfile_name ne q{}) {
   my $csv=Text::CSV_XS->new();
   print "Reading map:\n";
   open my $data_file,'<',$mapfile_name;
   while (my $line = $csv->getline($data_file)) {
      $i++;
      print ".";
      print "\r$i" unless $i % 100;

      my @data = @$line;
      $barcode_map{$data[0]} = $data[1];
   }
   close $data_file;
}

$i=0;
my %problem;
my %success;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO accountlines (borrowernumber, itemnumber, accountno, date, amount, description, note, accounttype, amountoutstanding)
        VALUES (?, ?, ?, ?,?, ?,?,?,?)");
my $sth_noitem = $dbh->prepare("INSERT INTO accountlines (borrowernumber,  accountno, date, amount, description, note, accounttype, amountoutstanding)
        VALUES (?,?,?,?,?,?,?,?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $thisitembar = "";

my $second_csv=Text::CSV_XS->new({binary => 1});
open my $in,'<',$infile_name;

MAINLOOP:
while (my $line = $second_csv->getline($in)){
   my @data = @$line;
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
print "\n Borrower not found: $thisbar ";
      next MAINLOOP;
   }
   $thisitembar = $data[4];
   if (exists $barcode_map{$data[4]}) {
      $thisitembar= $barcode_map{$data[4]};
   }

   $item_sth->execute($thisitembar);
   my $db_item_fetch=$item_sth->fetchrow_hashref();
   my $itemnum = $db_item_fetch->{'itemnumber'};
   my $transdate = _process_date2($data[2]);
   my $accountno  = getnextacctno($borrnum);
   my $amount = $data[6]/100;

   my $transdesc;
   my $accounttype;
   if ($data[3] eq "Lost Item Replacement") {
      $transdesc = "Lost Item Replacement";
      $accounttype = 'L';
   }
   elsif ($data[3] eq "Lost Item Processing") {
      $transdesc = "Lost Item Processing";
      $accounttype = 'L';
   }
   elsif ($data[3] eq "Non-resident Annual Fee") {
      $transdesc = "Non-resident Annual Fee ";
      $accounttype = 'A';
   }
   elsif ($data[3] eq "Overdue") {
      $transdesc = "Overdue - ";
      $accounttype = 'F';
   }
   else{
      $transdesc = $data[3];
      $accounttype = 'M';
   }
   if ($itemnum){
      $doo_eet and $sth->execute($borrnum,$itemnum,$accountno,$transdate,$amount,$transdesc,$data[5],$accounttype,$amount);
      $success{'fines inserted with item number present'}++;
   }
   if (!$itemnum){
      $doo_eet and $sth_noitem->execute($borrnum,$accountno,$transdate,$amount,$transdesc,$data[5],$accounttype,$amount);
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


sub _process_date2 {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq "";
   my ($month,$day,$year) = $datein =~ /(\d+).(\d+).(\d\d\d\d)/;
   if ($month && $day && $year) {
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
   }
   else {
      return undef;
   }
}



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
