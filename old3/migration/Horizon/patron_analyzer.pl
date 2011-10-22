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

my $csv = Text::CSV->new();
open my $infl,"<$infile_name";

my $i=0;
my $j=0;
my %profiles;
my $headerline = $csv->getline($infl);
my @fields = @$headerline;

while (my $line = $csv->getline($infl)) {
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   for (my $j=0;$j<scalar(@data);$j++){
      if ($fields[$j] eq "BType"){
         $profiles{$data[$j]}++;
      }
   }
}

print "\nRESULTS BY PROFILE\n";
foreach my $kee (sort keys %profiles){
   print $kee.":   ".$profiles{$kee}."\n";
}

exit if (!$create);

open my $out,">$outfile_name";

print $out "#\n# PATRON CATEGORIES \n#\n";
foreach my $kee (sort keys %profiles){
   print $out "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}

close $out;
