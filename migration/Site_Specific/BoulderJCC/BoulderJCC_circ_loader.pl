#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -Joy Nelson
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
my $sth = $dbh->prepare("INSERT INTO issues (borrowernumber, itemnumber, date_due, issuedate, branchcode) VALUES (?, ?, date(?), date(?), ?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT biblionumber,itemnumber FROM items WHERE barcode=?");
my $dum = $csv->getline($in);

MAINLOOP:
while (my $line = $csv->getline($in))
{
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   $item_sth->execute($data[2]);
   my $db_item_fetch=$item_sth->fetchrow_hashref();
   my $itemnum = $db_item_fetch->{'itemnumber'};
   my $biblionum = $db_item_fetch->{'biblionumber'};
   if (!$itemnum )
      {
      $problem{'items not found'}++;
      print "item not found: $data[2]\n";
      next MAINLOOP;
      }
   if ($data[0] ne "")
      {
      $borr_sth->execute($data[0]);
      my $db_borr_fetch=$borr_sth->fetchrow_hashref();
      my $borrnum=$db_borr_fetch->{'borrowernumber'};
      my $issuedate= $data[3];
      my $duedate = $data[1];
      if ($borrnum) 
         {
         $doo_eet and $sth->execute($borrnum,$itemnum,$duedate,$issuedate,$branch);
         $success{'items checked out to borrower'}++;
         }
      else 
         {
         $problem{'borrowers not found'}++;
         print "borrower not found: $data[0]\n";
         }
      }
}

close $in;

print "\n\n$i lines read.\n";
foreach my $kee (sort keys %success)
{
   print "$success{$kee} $kee\n";
}

print "\nProblems:\n";
foreach my $kee (sort keys %problem)
{
   print "$problem{$kee} $kee\n";
}
   
exit;

