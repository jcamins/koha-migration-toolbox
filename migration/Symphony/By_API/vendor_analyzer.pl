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
my %tags;
my %addrtags;
my %xinfotags;
my $addr1;
my $addr2;
my $addr3;
my $xinfo;
my $note;

while (my $line = readline($in)) {
   chomp $line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($line =~ /DOCUMENT BOUNDARY/){
      $addr1=0;
      $addr2=0;
      $addr3=0;
      $xinfo=0;
      $j++;
      next;
   }
   $line =~ /^\.([\w\/]+)\./;
   my $thistag = $1;
   $note = 0 if ($thistag);
   $note = 1 if (($thistag eq "NOTE") or ($thistag eq "COMMENT") or ($thistag eq "WEBCATPREF"));
   next if (($thistag eq "") && $note);
   if ($thistag eq "VEND_ADDR1_BEGIN"){
      $addr1=1;
      next;
   }
   if ($thistag eq "VEND_ADDR1_END"){
      $addr1=0;
      next;
   }
   if ($thistag eq "VEND_ADDR2_BEGIN"){
      $addr2=1;
      next;
   }
   if ($thistag eq "VEND_ADDR2_END"){
      $addr2=0;
      next;
   }
   if ($thistag eq "VEND_ADDR3_BEGIN"){
      $addr3=1;
      next;
   }
   if ($thistag eq "VEND_ADDR3_END"){
      $addr3=0;
      next;
   }
   if ($thistag eq "VEND_XINFO_BEGIN"){
      $xinfo=1;
      next;
   }
   if ($thistag eq "VEND_XINFO_END"){
      $xinfo=0;
      next;
   }
   if ($addr1){
      $debug and print $line."\n" if ($thistag eq "");
      $addrtags{1}{$thistag}++;
      next;
   }
   if ($addr2){
      $debug and print $line."\n" if ($thistag eq "");
      $addrtags{2}{$thistag}++;
      next;
   }
   if ($addr3){
      $debug and print $line."\n" if ($thistag eq "");
      print $line."\n";
      $addrtags{3}{$thistag}++;
      next;
   }
   if ($xinfo){
      $debug and print $line."\n" if ($thistag eq "");
      $xinfotags{$thistag}++;
      next;
   }
   $debug and print $line if ($thistag eq "");
   $tags{$thistag}++;
}

print "\n\n$i lines read.\n$j records found.\n";
print "\nRESULTS BY TAG\n";
foreach my $kee (sort keys %tags){
   print $kee.":   ".$tags{$kee}."\n";
}

print "\nRESULTS BY ADDRESSTAG\n";
for (my $k=1;$k<4;$k++){
   foreach my $kee (sort keys %{$addrtags{$k}}){
      print "ADDR$k--".$kee.":   ".$addrtags{$k}{$kee}."\n";
   }
}

print "\nRESULTS BY XINFOTAG\n";
foreach my $kee (sort keys %xinfotags){
   print $kee.":   ".$xinfotags{$kee}."\n";
}
