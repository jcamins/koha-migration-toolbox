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
use Encode;
use Getopt::Long;
use Text::CSV;
use Text::CSV::Simple;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $mapfile_name = "";
my %bill_reason_map;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$mapfile_name,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

open my $map,"<$mapfile_name";
my $csv=Text::CSV->new();
while (my $row = $csv->getline($map)){
   my @data = @$row;
   $bill_reason_map{$data[0]} = $data[1];
}
close $map;

my $i=0;
my $written=0;
my %reasons;

my %thisrow;
my $nextline=0;
my @charge_fields= qw{ borrowerbar date amount reason description};

open my $infl,"<$infile_name" || die ('problem opening $infile_name');
open my $outfl,">",$outfile_name || die ('problem opeining $outfile_name');
for my $j (0..scalar(@charge_fields)-1){
   print $outfl $charge_fields[$j].',';
}
print $outfl "\n";

LINE:
while (my $line = readline($infl)){
   last LINE if ($debug && $written >50);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   chomp $line;
   $line =~ s///g;
   next LINE if $line eq q{};
   next LINE if $line =~ /Bill List/;
   next LINE if $line =~ /^\s+$/;
   next LINE if $line =~ /^NAME/;
   next LINE if $line =~ /AMOUNT/;
   next LINE if $line =~ /          Produced /;

   if ($line =~ /copy:/){
      $nextline = 1;
      next LINE;
   }

   if ($nextline){
      $line =~ s/^  //g;
      $thisrow{description} = $line;
      $nextline = 0;
      next LINE;
   }

   next LINE if $line =~ /^  \w/;
   
   if ($line =~ /^\w/){
      if ($thisrow{amount} ne ".00"){
         if (exists $bill_reason_map{$thisrow{reason}}){
            $thisrow{reason} = $bill_reason_map{$thisrow{reason}};
         }
         $reasons{$thisrow{reason}}++;
         for my $j (0..scalar(@charge_fields)-1){
            if ($thisrow{$charge_fields[$j]}){
               $thisrow{$charge_fields[$j]} =~ s/\"/'/g;
               if ($thisrow{$charge_fields[$j]} =~ /,/){
                  print $outfl '"'.$thisrow{$charge_fields[$j]}.'"';
               }
               else{
                  print $outfl $thisrow{$charge_fields[$j]};
               }
            }
            print $outfl ",";
         }
         print $outfl "\n";
         $written++;
      }
      %thisrow=();

      $line =~ m[ (\w+)\s+(\d+)\/(\d+)\/(\d+)\,];
      $thisrow{borrowerbar} = $1;
      $thisrow{date} = sprintf "%4d-%02d-%02d",$4,$2,$3;
      next LINE;
   }

   if ($line =~ m[\$[\d.]+\s+(\w+)\s+\$([\d.]+)]){
      $thisrow{reason} = $1;
      $thisrow{amount} = $2;
      next LINE;
   }

   if ($line eq q{}){
      next LINE if !%thisrow;
   }
}

close $infl;
close $outfl;

print "\n\n$i lines read.\n$written charges written.\n";
print "REASONS:\n";
foreach my $key (sort keys %reasons){
   print "$key:  $reasons{$key}\n";
}
exit;
