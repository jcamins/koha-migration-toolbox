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

GetOptions(
    'in=s'            => \$infile_name,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $k=0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("UPDATE borrowers SET borrowernotes=? WHERE borrowernumber=?");
my $borr_sth = $dbh->prepare("SELECT borrowernumber,borrowernotes FROM borrowers WHERE cardnumber=?");

my $thisborrowerbar;
RECORD:
while (my $line = readline($in)) {
   last if ($debug and $i>10);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   my $finalnote=q{};
   my @data = split /,/ ,$line, 2;
   #$debug and print Dumper(@data);
   next RECORD if $data[1] eq '.';
   $borr_sth->execute($data[0]);
   my $hash=$borr_sth->fetchrow_hashref();
   my $borrnumber = $hash->{'borrowernumber'};
   my $currnotes = $hash->{'borrowernotes'};
   if ($currnotes){
      $finalnote = $currnotes."\n".$data[1];
   }
   else {
      $finalnote = $data[1];
   }
   $debug and print "BORROWER:$data[0] ($borrnumber)\n$finalnote\n";
   if ($borrnumber && $doo_eet){
      $sth->execute($finalnote,$borrnumber);
   }
   $j++;
}

close $in;

print "\n\n$i lines read.\n$j notes loaded.\n";
exit;
