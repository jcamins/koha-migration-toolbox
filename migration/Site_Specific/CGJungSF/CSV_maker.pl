#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use warnings;
use strict;
use Getopt::Long;
$|=1;

my $infile_name = "";
my $outfile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
    'out=s'    => \$outfile_name,
);

if (($infile_name eq q{}) || ($outfile_name eq q{})){
   print "You're missing something.\n";
   exit;
}

my $i=0;
my $j=0;
my $keep = q{};

open my $in,"<",$infile_name;
open my $out,">",$outfile_name;

LINE:
while (my $line=readline($in)){
   $i++;
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s///g;
   if ($line eq q{}){
      if ($keep ne q{}){
         my @data = split (/\|/,$keep);
         for my $k (0..scalar(@data)-1){
            if ($data[$k] ne q{}){
               $data[$k] =~ s/^\s+//;
               $data[$k] =~ s/\s+$//;
               $data[$k] =~ s/"/'/g;
               if ($data[$k] =~ /,/ || $data[$k] =~ /\"/){
                  print $out '"'.$data[$k].'"';
               }
               else{
                  print $out $data[$k];
               }
            }
            print $out ',';
         }
         print $out "\n";
      }

      $keep = q{};   
      $j++; 
      next LINE;
   }
   $keep .= ' '.$line;
}

close $in;
close $out;

print "\n\n$i records read.\n$j lines written.\n";

