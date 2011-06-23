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
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $i=0;
my $csv=Text::CSV->new({binary => 1,sep_char => '|'});
my %quintmap;
open my $infl,"<",$infile_name;
LINE:
while (my $line = $csv->getline($infl)){
   last LINE if ($debug and $i>0);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my @data=@$line;
   $debug and print Dumper(@data);
   my $hashkee = "$data[6]:$data[2]:$data[3]:$data[4]:$data[5]";
   $quintmap{$hashkee}++;
}
close $infl;

open my $outfl,">",$outfile_name;
foreach my $kee (sort keys %quintmap){
   print {$outfl} "$kee:$quintmap{$kee}\n";
}
close $outfl;
