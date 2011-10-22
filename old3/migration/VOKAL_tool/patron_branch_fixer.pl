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
use C4::Members;
$|=1;

my $infile_name = "";
my $debug =0;
my $doo_eet=0;

GetOptions(
    'in=s'     => \$infile_name,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq '')){
   print "You're missing something.\n";
   exit;
}

my $csv=Text::CSV->new();
my $dbh=C4::Context->dbh();
my $i=0;
my $j=0;
open my $io,"<$infile_name";
my $sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber LIKE ? AND branchcode != ?");
while (my $row=$csv->getline($io)){
   $debug and last if ($j>0);
   my @data=@$row;
   $i++;
   print "\n.";
   $sth->execute($data[0]."%",$data[1]);
   while (my $line=$sth->fetchrow_hashref()){
      $debug and last if ($j>10);
      $j++;
      print "*";
      print "$j\r" unless ($j % 100);
      $debug and print "Modifying borrower $line->{'borrowernumber'} to $data[1]\n";
      $doo_eet and C4::Members::ModMember(borrowernumber => $line->{'borrowernumber'}, branchcode => $data[1]);
   }
}

print "\n$i map lines read.\n$j borrowers modified.\n";
