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
my $outfile_name = "";
my $create = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'create'        => \$create,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($create && $outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my %libraries;
my %profiles;
my %usercats;
my %statuses;
my %mailingaddr;
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
   $line =~ s/$//;
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
   $line =~ /\|a(.*)/;
   my $content = $1;
   $profiles{$content}++ if ($thistag eq "USER_PROFILE");
   $libraries{$content}++ if ($thistag eq "USER_LIBRARY");
   $statuses{$content}++ if ($thistag eq "USER_STATUS");
   $mailingaddr{$content}++ if ($thistag eq "USER_MAILINGADDR");
   $usercats{1}{$content}++ if ($thistag eq "USER_CATEGORY1");
   $usercats{2}{$content}++ if ($thistag eq "USER_CATEGORY2");
   $usercats{3}{$content}++ if ($thistag eq "USER_CATEGORY3");
   $usercats{4}{$content}++ if ($thistag eq "USER_CATEGORY4");
   $usercats{5}{$content}++ if ($thistag eq "USER_CATEGORY5");
   if ($thistag eq "USER_ADDR1_BEGIN"){
      $addr1=1;
      next;
   }
   if ($thistag eq "USER_ADDR1_END"){
      $addr1=0;
      next;
   }
   if ($thistag eq "USER_ADDR2_BEGIN"){
      $addr2=1;
      next;
   }
   if ($thistag eq "USER_ADDR2_END"){
      $addr2=0;
      next;
   }
   if ($thistag eq "USER_ADDR3_BEGIN"){
      $addr3=1;
      next;
   }
   if ($thistag eq "USER_ADDR3_END"){
      $addr3=0;
      next;
   }
   if ($thistag eq "USER_XINFO_BEGIN"){
      $xinfo=1;
      next;
   }
   if ($thistag eq "USER_XINFO_END"){
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

print "\n\n$i lines read.\n$j borrowers found.\n";
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

print "\nRESULTS BY LIBRARY\n";
foreach my $kee (sort keys %libraries){
   print $kee.":   ".$libraries{$kee}."\n";
}

print "\nRESULTS BY STATUS\n";
foreach my $kee (sort keys %statuses){
   print $kee.":   ".$statuses{$kee}."\n";
}

print "\nRESULTS BY PROFILE\n";
foreach my $kee (sort keys %profiles){
   print $kee.":   ".$profiles{$kee}."\n";
}

print "\nRESULTS BY MAILINGADDR\n";
foreach my $kee (sort keys %mailingaddr){
   print $kee.":   ".$mailingaddr{$kee}."\n";
}

print "\nRESULTS BY USERCAT\n";
for (my $k=1;$k<6;$k++){
   foreach my $kee (sort keys %{$usercats{$k}}){
      print "CAT$k--".$kee.":   ".$usercats{$k}{$kee}."\n";
   }
}

exit if (!$create);

open my $out,">$outfile_name";

print $out "#\n# BRANCHES \n#\n";
foreach my $kee (sort keys %libraries){
   print $out "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print $out "#\n# PATRON CATEGORIES \n#\n";
foreach my $kee (sort keys %profiles){
   print $out "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}

close $out;
