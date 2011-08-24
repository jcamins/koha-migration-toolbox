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
use Getopt::Long;
$|=1;
my $debug=0;

my $infile_name = "";

GetOptions(
    'in=s'          => \$infile_name,
    'debug'         => \$debug,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $billsum=0;
my %reasons;

while (my $line = readline($in)) {
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   next if ($line =~ /FORM=LDBILL/);
   if ($line =~ /DOCUMENT BOUNDARY/){
      $j++;
      next;
   }
   $line =~ /^\.([\w\/]+)\./;
   my $thistag = $1;
   $line =~ /\|a(.*)/;
   my $content = $1;
   $content =~ s/\$//;
   $reasons{$content}++ if ($thistag eq "BILL_REASON");
   $billsum += ($content*100) if ($thistag eq "BILL_AMOUNT");

}

close $in;

print "\n\n$i lines read.\n$j bills found.\n";
$billsum /= 100;
print "Bills total $billsum\n\n";
print "\nRESULTS BY REASON\n";
foreach my $kee (sort keys %reasons){
   print $kee.":   ".$reasons{$kee}."\n";
}

