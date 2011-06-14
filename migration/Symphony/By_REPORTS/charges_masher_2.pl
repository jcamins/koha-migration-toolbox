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
my $fixed_branch = "";
my $branch_map_name = "";
my %branch_map;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'branch=s'      => \$fixed_branch,
    'branch_map=s'  => \$branch_map_name,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
if ($branch_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$branch_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $i=0;
my $written=0;

my %thisrow;
my @charge_fields= qw{ borrowerbar itembar   chargedate branchcode
                       duedate     renewdate renewals };


open my $infl,"<$infile_name" || die ('problem opening $infile_name');
open my $outfl,">",$outfile_name || die ('problem opeining $outfile_name');
for my $j (0..scalar(@charge_fields)-1){
   print $outfl $charge_fields[$j].',';
}

LINE:
while (my $line = readline($infl)){
   last LINE if ($debug && $written >50);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   chomp $line;
   $line =~ s///g;
   next LINE if $line eq q{};
   next LINE if $line =~ /Charge List/;
   next LINE if $line =~ /^     /;
   next LINE if $line =~ /USER NAME/;
   next LINE if $line =~ /^DUE/;
   next LINE if $line =~ /^LOCATION/;
   next LINE if $line =~ /^ \w/;

   if ($line =~ /copy:/){
      $line =~ /(\d+)\s+$/;
      $thisrow{itembar} =$1;
      next LINE;
   }
   
   if ($line =~ /^  \w/){
      $line =~ m[ (\w+)\s+(\d+)\/(\d+)\/(\d+)\,];
      $thisrow{borrowerbar} = $1;
      $thisrow{chargedate} = sprintf "%4d-%02d-%02d",$4,$2,$3;
      next LINE;
   }

   if ($line =~ m[^(\d+)/(\d+)/(\d+),]){
      $thisrow{duedate} = sprintf "%4d-%02d-%02d",$3,$1,$2;
      if ($line =~ m[ (\d+)/(\d+)/(\d+),\d+:\d+\s+(\d+)\s+]  ){
         $thisrow{renewdate} = sprintf "%4d-%02d-%02d",$3,$1,$2;
         $thisrow{renewals}  = $4;
      }
      else{
         $thisrow{renewals} = 0;
      }
      next LINE;
   }

   if ($line =~ /^\w+\s+(\w+)/){
      $thisrow{branchcode} = $1;

      if ($fixed_branch && $thisrow{branchcode} eq q{} ){
         $thisrow{branchcode} = $fixed_branch;
      } 

      if ($branch_map{$thisrow{branchcode}}){
         $thisrow{branchcode} = $branch_map{$thisrow{branchcode}};
      }

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
      %thisrow=();
      next LINE;
   }
}

close $infl;
close $outfl;

print "\n\n$i lines read.\n$written charges written.\n";
exit;
