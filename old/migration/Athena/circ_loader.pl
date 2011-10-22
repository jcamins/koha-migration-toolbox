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
use Date::Calc qw(Add_Delta_Days);
use C4::Context;
use C4::Items;
use MARC::Record;
use MARC::Field;
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
my $sth = $dbh->prepare("INSERT INTO issues (borrowernumber, itemnumber, date_due, issuedate, branchcode) VALUES (?, ?, ?, ?, ?)");
my $rsv_sth = $dbh->prepare("INSERT INTO reserves
                 (borrowernumber,reservedate,biblionumber,branchcode, found,itemnumber, waitingdate,expirationdate)
                  VALUES (?, ?, ?, ?, 'W', ?, ?, ?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT biblionumber,itemnumber FROM items WHERE barcode=?");
my $dum = $csv->getline($in);

MAINLOOP:
while (my $line = $csv->getline($in)){
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   $item_sth->execute($data[3]);
   my $db_item_fetch=$item_sth->fetchrow_hashref();
   my $itemnum = $db_item_fetch->{'itemnumber'};
   my $biblionum = $db_item_fetch->{'biblionumber'};
   if (!$itemnum && $data[1] ne "U"){
      $problem{'items not found'}++;
      next MAINLOOP;
   }
   if ($data[1] ne "K" && $data[1] ne "G" && $data[4] ne ""){
      $borr_sth->execute($data[4]);
      my $db_borr_fetch=$borr_sth->fetchrow_hashref();
      my $borrnum=$db_borr_fetch->{'borrowernumber'};
      my $issuedate=_process_date($data[5]);
      my $duedate = _process_date($data[7]);
      if ($borrnum){
         $doo_eet and $sth->execute($borrnum,$itemnum,$duedate,$issuedate,$branch);
         $success{'items checked out to borrower'}++;
      }
      elsif ($data[1] eq "C"){
      $debug and print Dumper(@data);
         $debug and print "Borr notfound: $data[1] $data[4]\n";
         $problem{'borrowers not found'}++;
      }
   }
   if ($data[1] eq "D"){
      $doo_eet and ModItem({ damaged => 1, },undef,$itemnum);
      $success{'items marked damaged'}++;
   }
   if ($data[1] eq "G"){
      $doo_eet and ModItem({ itemlost => 3, },undef,$itemnum);
      $success{'items marked lost and paid for'}++;
   }
   if ($data[1] eq "K"){
      $borr_sth->execute($data[4]);
      my $db_borr_fetch=$borr_sth->fetchrow_hashref();
      my $borrnum=$db_borr_fetch->{'borrowernumber'};
      my $reservedate=_process_date($data[5]);
      my $expirationdate = _process_exp_date($data[5]);
      if ($borrnum){
         $rsv_sth->execute($borrnum,$reservedate,$biblionum,$branch,$itemnum, $reservedate,$expirationdate);
         $success{'trapped reserves added'}++;
      }
      else{
         $problem{'borrowers not found'}++;
      }
   }
   if ($data[1] eq "L"){
      $doo_eet and ModItem({ itemlost => 1, },undef,$itemnum);
      $success{'items marked lost'}++;
   }
   if ($data[1] eq "M"){
      $doo_eet and ModItem({ itemlost => 4, },undef,$itemnum);
      $success{'items marked missing'}++;
   }
   if ($data[1] eq "T"){
      $doo_eet and ModItem({ itemlost => 5, },undef,$itemnum);
      $success{'items marked claims-returned'}++;
   }
   if ($data[1] eq "W"){
      $doo_eet and ModItem({ wthdrawn => 1, },undef,$itemnum);
      $success{'items marked withdrawn'}++;
   }
   if ($data[1] eq "U"){
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
sub _process_exp_date {
   my $datein= shift;
   return "" if ($datein eq "");
   my ($month,$day,$year) = split(/\//,$datein);
   if ($year <=40){
      $year += 2000;
   }
   else {
      $year += 1900;
   }
   ($year,$month,$day) = Add_Delta_Days($year,$month,$day,8);
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
