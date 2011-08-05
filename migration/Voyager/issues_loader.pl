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
my $doo_eet=0;

my $infile_name = "";
my $branch = "";
my $use_inst_id = "";

GetOptions(
    'in=s'            => \$infile_name,
    'branch=s'        => \$branch,
    'use_inst'        => \$use_inst_id,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '') ){
  print "Something's missing.\n";
  exit;
}

my $csv = Text::CSV->new();
open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $problem=0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO issues (borrowernumber, itemnumber, date_due, issuedate, branchcode, renewals) VALUES (?, ?, ?, ?, ?, ?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $thisborrower;
RECORD:
while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;

   my $thisborrowerbar = $data[0];
   if ($use_inst_id){
      $thisborrowerbar = $data[1];
   }
   if ($thisborrowerbar eq q{}){
      $thisborrowerbar = sprintf "TEMP%d",$data[2];
   }
  
   $borr_sth->execute($thisborrowerbar);
   my $hash=$borr_sth->fetchrow_hashref();
   $thisborrower=$hash->{'borrowernumber'};

   my $thisitembar = $data[3];
   $item_sth->execute($thisitembar);
   $hash=$item_sth->fetchrow_hashref();
   my $thisitem = $hash->{'itemnumber'};
  
   my $thisdateout = _process_date($data[4]);
   my $thisdatedue = _process_date($data[5]);
   my $renewals = 0;
   if ($data[4] ne q{}){
      $renewals = $data[6];
   }

   if ($thisborrower && $thisitem){
      $j++;
      $debug and print "B:$thisborrowerbar I:$thisitembar O:$thisdateout D:$thisdatedue R:$renewals\n";
      if ($doo_eet){
         $sth->execute($thisborrower,
                       $thisitem,
                       $thisdatedue,
                       $thisdateout,
                       $branch,
                       $renewals);
         C4::Items::ModItem({itemlost         => 0,
                             datelastborrowed => $thisdateout,
                             datelastseen     => $thisdateout,
                             onloan           => $thisdatedue,
                            },undef,$thisitem);
      }
   }
   else{
      print "\nProblem record:\n";
      print "B:$thisborrowerbar ($thisborrower) I:$thisitembar ($thisitem) O:$thisdateout D:$thisdatedue\n";
      $problem++;
   }
   last if ($debug && $j>20);
   next;
}

close $in;

print "\n\n$i lines read.\n$j issues loaded.\n$problem problem issues not loaded.\n";
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
