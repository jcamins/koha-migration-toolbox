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
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";

GetOptions(
    'in=s'            => \$infile_name,
    'out=s'           => \$outfile_name,
    'debug'           => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
my $csv = Text::CSV->new();
open my $in,"<$infile_name";
open my $out,">",$outfile_name;
my $i=0;
my $j=0;
for (1..6){
   my $dum = readline($in);   #get past the header.
}
my %thisborr;
my $line_tick = 0;
RECORD:
while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
  
   if ($data[3] eq 'Good' || $data[3] eq 'Blocked' 
       || $data[4] eq 'Good' || $data[4] eq 'Blocked'){
      if ($thisborr{cardnumber}){               
         print {$out} "$thisborr{cardnumber},$thisborr{categorycode}\n";
         $j++;
      }
      $line_tick=1;
      next RECORD;
   } 
   
   if ($line_tick == 1){
      %thisborr=();
      $thisborr{cardnumber} = $data[1];
      $line_tick = 2;
      next RECORD;
   }

   if ($line_tick > 1 ){
      if ($data[0] =~ /^[A-Z]+$/){
         $thisborr{categorycode} = $data[0];
         $line_tick=0;
      }
      next RECORD;
   }
}

if ($thisborr{cardnumber}){               
   print {$out} "$thisborr{cardnumber},$thisborr{categorycode}\n";
   $j++;
}
close $in;

print "\n\n$i lines read.\n$j borrowers written.\n";
exit;
