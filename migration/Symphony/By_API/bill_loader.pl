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

my $infile_name = "";
my $mapfile_name = "";

GetOptions(
    'in=s'          => \$infile_name,
    'map=s'         => \$mapfile_name,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($mapfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my %bill_reason_map;
open my $map,"<$mapfile_name";
my $csv=Text::CSV->new();
while (my $row = $csv->getline($map)){
   my @data = @$row;
   $bill_reason_map{$data[0]} = $data[1];
}
close $map;

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $problem=0;
my $billsum=0;
my %thisbill=();

my $dbh= C4::Context::dbh();

my $sth2=$dbh->prepare("INSERT INTO accountlines
                       (borrowernumber,itemnumber,date,amount,description,accounttype,
                              amountoutstanding,lastincrement,accountno)
                        VALUES (?,?,?,?,?,?,?,?,?)");

my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
my $item_sth = $dbh->prepare("SELECT itemnumber,title FROM items 
                               LEFT JOIN biblio ON (items.biblionumber=biblio.biblionumber)
                               WHERE barcode = ?");


while (my $line = readline($in)) {
   $debug and last if ($j>0);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   next if ($line =~ /FORM=LDBILL/);
   next if (($line =~ /DOCUMENT BOUNDARY/) && !%thisbill);
   if (($line =~ /DOCUMENT BOUNDARY/) && %thisbill){
      $debug and print Dumper(%thisbill);
      my $description = $thisbill{'orig_reason'} ." fine migrated from Unicorn";
      if ($thisbill{'itemnumber'}){
         $description .= " on ".$thisbill{'title'}." (".$thisbill{'itembar'}.")";
      }
      if ($thisbill{'borrowernumber'}){
         my $nextacctnum = C4::Accounts::getnextacctno($thisbill{'borrowernumber'});
         $sth2->execute($thisbill{'borrowernumber'},
                     $thisbill{'itemnumber'},
                     $thisbill{'billdate'},
                     $thisbill{'amount'},
                     $description,
                     $thisbill{'accounttype'},
                     $thisbill{'amount'},
                     $thisbill{'amount'},
                     $nextacctnum);
         $j++;
      }
      else {
         print "\nProblem:\n----------------\n";
         print Dumper(%thisbill);
         $problem++;
      }
      %thisbill=();
      next;
   }
   $line =~ /^\.([\w\/]+)\./;
   my $thistag = $1;
   $line =~ /\|a(.*)/;
   my $content = $1;
   $content =~ s/\$//;

   if ($thistag eq "USER_ID"){
      $borr_sth->execute($content);
      my $hash = $borr_sth->fetchrow_hashref();
      $thisbill{'borrowernumber'} = $hash->{'borrowernumber'};
      $thisbill{'borrowerbar'} = $content;
      next;
   }
   if ($thistag eq "ITEM_ID"){
      $item_sth->execute($content);
      my $hash = $item_sth->fetchrow_hashref();
      $thisbill{'itemnumber'} = $hash->{'itemnumber'};
      $thisbill{'title'} = $hash->{'title'};
      $thisbill{'itembar'} = $content;
      next;
   }

   $thisbill{'billdate'} = _process_date($content) if ($thistag eq "BILL_DB");
   if ($thistag eq "BILL_AMOUNT"){
      $billsum += ($content*100);
      $thisbill{'amount'} = $content;
   }
   
   if ($thistag eq "BILL_REASON"){
      if (exists $bill_reason_map{$content}){
         $thisbill{'reason'} = $bill_reason_map{$content};
      }
      else {
         $thisbill{'reason'} = $content;
      }
      $thisbill{'orig_reason'} = $content;
   }
}

close $in;

# Got to write the final one!
#
if ($thisbill{'borrowernumber'}){
   my $description = $thisbill{'orig_reason'} ." fine migrated from Unicorn";
   if ($thisbill{'itemnumber'}){
      $description .= " on ".$thisbill{'title'}." (".$thisbill{'itembar'}.")";
   }
   my $nextacctnum = C4::Accounts::getnextacctno($thisbill{'borrowernumber'});
   $sth2->execute($thisbill{'borrowernumber'},
               $thisbill{'itemnumber'},
               $thisbill{'billdate'},
               $thisbill{'amount'},
               $description,
               $thisbill{'accounttype'},
               $thisbill{'amount'},
               $thisbill{'amount'},
               $nextacctnum);
   $j++;
}

print "\n\n$i lines read.\n$j bills loaded.\n$problem problem bills dropped.\n";
$billsum /= 100;
print "Bills total $billsum\n\n";

exit;

sub _process_date {
    my ($date_in) = @_;
    return "" if ($date_in eq "NEVER");
    my $year = substr($date_in,0,4);
    my $month = substr($date_in,4,2);
    my $day = substr($date_in,6,2);
    return sprintf "%d-%02d-%02d",$year,$month,$day;
}
