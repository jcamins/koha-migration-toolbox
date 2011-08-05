#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Getopt::Long;
use Text::CSV_XS;
$|=1;

my $infile_name = q{};
my $outfile_name = q{};
my $delimiter = '|';

GetOptions(
    'in=s'        => \$infile_name,
    'out=s'       => \$outfile_name,
    'delim=s'     => \$delimiter,
);

if (($infile_name eq q{}) || ($outfile_name eq q{})){
   print "You're missing something.\n";
   exit;
}

my $csv=Text::CSV_XS->new();
my $i=0;
my $j=0;
my $carryline=q{};
open my $in,"<",$infile_name;
open my $out,">",$outfile_name;
LINE:
while (my $line=readline($in)){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s///g;
   next LINE if ($line eq q{});
   if ($line !~ /^\d+,/m){
      $carryline .= $delimiter.$line;
      next LINE;
   }
   else{
      if ($carryline ne q{}){
         print {$out} $carryline."\n";
         $j++;
      }
      $carryline = $line;
   }
}
close $out;
close $in;

print "\n$i lines read.\n$j lines written.\n";
