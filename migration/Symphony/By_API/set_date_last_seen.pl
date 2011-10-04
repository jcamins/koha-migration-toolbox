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
my $i=0;

my $infile_name = "";
my $bogus_date = "";
my $doo_eet = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'bogus=s'       => \$bogus_date,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $written;

open my $infl,"<$infile_name";
ITEM:
while (my $itmline = readline($infl)){
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $itmline;
   $itmline =~ s///g;
   my ($catkey,$barcode,$rest)= split(/\|/,$itmline,3);
   $barcode =~ s/ //g;
   my $item= GetItem(undef,$barcode);
   next ITEM if !$item;
   next ITEM if ($item->{datelastseen} ne $bogus_date);

   my (undef,undef,undef,undef,undef,$tmpseen,undef) = split(/\|/,$rest,7);
   my $seendate;

   if ($tmpseen){
      my $year=substr($tmpseen,0,4);
      my $month=substr($tmpseen,4,2);
      my $day=substr($tmpseen,6,2);
      if ($month && $day && $year){
         $seendate = sprintf "%4d-%02d-%02d",$year,$month,$day;
      }
   }
   if ($seendate){
      $debug and print "Barcode: $barcode Seen: $seendate\n";
      if ($doo_eet){
         C4::Items::ModItem({datelastseen=>$seendate},undef,$row->{itemnumber});
      }
      $written++;
   } 
}
close $infl;

print "\n$i lines read.\n$written items modified.\n";

