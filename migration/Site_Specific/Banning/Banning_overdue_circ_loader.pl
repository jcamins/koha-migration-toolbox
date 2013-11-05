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
use Text::CSV_XS;
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

my $csv = Text::CSV_XS->new( {binary=>1} );
open my $in,"<$infile_name";
my $i=0;
my %problem;
my %success;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO issues (borrowernumber, itemnumber, date_due, branchcode, issuedate) VALUES (?,?, ?, ?, ?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $issues_sth = $dbh->prepare("SELECT date_due from issues where itemnumber=?");
my $dum = $csv->getline($in);
my $existing_issue_record=0;

MAINLOOP:
while (my $line = $csv->getline($in))
{
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   $item_sth->execute($data[7]);
   my $db_item_fetch=$item_sth->fetchrow_hashref();
   my $itemnum = $db_item_fetch->{'itemnumber'};
   if (!$itemnum )
      {
      $problem{'items not found'}++;
      print "item not found: $data[7]: $data[9]\n";
      next MAINLOOP;
      }
#$data[1] is patron barcode
   if ($data[1] ne "") {
      $data[1] =~ s/ //g; 
      $borr_sth->execute($data[1]);
      my $db_borr_fetch=$borr_sth->fetchrow_hashref();
      my $borrnum=$db_borr_fetch->{'borrowernumber'};
      my $existingissue;

      if ($borrnum) {
         $issues_sth->execute($itemnum);
         my $existing_fetch = $issues_sth->fetchrow_hashref();
         $existingissue=$existing_fetch->{'date_due'};
         if ($existingissue) {
          $existing_issue_record++;
          }
         }
      else
         {
         $problem{'borrowers not found'}++;
         print "borrower not found: $data[1]: $data[0]\n";
         }

      my $duedate = $data[5];
      if ( ($borrnum) && (!$existingissue) ) 
         {
         $doo_eet and $sth->execute($borrnum,$itemnum,$duedate,$branch,$duedate);
         $success{'items checked out to borrower'}++;
         }
      }
}

close $in;

print "\n\n$i lines read.\n";
foreach my $kee (sort keys %success)
{
   print "$success{$kee} $kee\n";
}

print "$existing_issue_record existing issue records found - not loaded a second time\n";

print "\nProblems:\n";
foreach my $kee (sort keys %problem)
{
   print "$problem{$kee} $kee\n";
}
   
exit;

