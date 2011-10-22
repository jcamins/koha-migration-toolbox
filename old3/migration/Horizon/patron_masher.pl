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
my $patron_cat_mapfile = "";
my %patron_cat_map;
my $branch = "";
my $emailfile = "";

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$patron_cat_mapfile,
    'email=s'       => \$emailfile,
    'debug'         => \$debug,
    'branch=s'      => \$branch,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

if ($patron_cat_mapfile){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$patron_cat_mapfile";
   while (my $row = $csv->getline($mapfile)){
      my @data=@$row;
      $patron_cat_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my %email;
if ($emailfile){
   my $csv=Text::CSV->new();
   open my $email_in,"<$emailfile";
   while (my $row= $csv->getline($email_in)){
      my @data=@$row;
      $email{$data[0]} = $data[1];
   }
   close $email_in;
}

my $csv = Text::CSV->new();
open my $in,"<$infile_name";

my $i=0;
my $j=0;
my %profiles;
my $headerline = $csv->getline($in);
my @fields = @$headerline;
my @borrowers;
my %headerkees;

while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my %thisborrower;
   for (my $j=0;$j<scalar(@data);$j++){
      if ($branch){
         $thisborrower{'branchcode'} = $branch;
      }

      if ($fields[$j] eq "Name"){
         my ($last,$first) = split(/,/,$data[$j]);
         $first =~ s/^ // if ($first);
         $thisborrower{'surname'} = $last;
         $thisborrower{'firstname'} = $first;
      }
      if ($fields[$j] eq "Creation Date"){
         my ($month,$day,$year) = split(/\//,$data[$j]);
         if ($year <=11){ 
            $year += 2000;
         }
         else {
            $year += 1900;
         }
         $thisborrower{'dateenrolled'} = sprintf "%4d-%02d-%02d",$year,$month,$day;
      }
      if ($fields[$j] eq "Exp. Date"){
         my ($month,$day,$year) = split(/\//,$data[$j]);
         if ($year <=48){ 
            $year += 2000;
         }
         else {
            $year += 1900;
         }
         $thisborrower{'dateexpiry'} = sprintf "%4d-%02d-%02d",$year,$month,$day;
      }
      if ($fields[$j] eq "borrower#"){
         $thisborrower{'cardnumber'} = $data[$j];
      }
      if ($fields[$j] eq "BType"){
         if (exists $patron_cat_map{$data[$j]}){
            $debug and warn "Swapping cat $data[$j] to $patron_cat_map{$data[$j]}.";
            $thisborrower{'categorycode'} = $patron_cat_map{$data[$j]};
            next;
         } 
         else {
            $thisborrower{'categorycode'} = $data[$j];
         }
      }
      if ($fields[$j] eq "Second ID"){
         $thisborrower{'userid'} = $data[$j];
      }
      if ($fields[$j] eq "Pin number"){
         $thisborrower{'password'} = $data[$j];
      }
      if ($fields[$j] eq "Borrower Note"){
         $thisborrower{'borrowernotes'} = $data[$j];
      }
   }
   if (%thisborrower){
      $thisborrower{'email'} = $email{$thisborrower{'cardnumber'}};
      $j++;
      push @borrowers,{%thisborrower};
      foreach my $kee ( sort keys %thisborrower){
         $headerkees{$kee} = 1;
      }
   }
}
print "\n\n$i lines read.\n$j borrowers found.\n";

open my $out,">$outfile_name";
foreach my $kee (sort keys %headerkees){
   print $out $kee.",";
}
print $out "\n";
for (my $j=0;$j<scalar(@borrowers);$j++){
   foreach my $kee (sort keys %headerkees){
      if ($borrowers[$j]{$kee}){
         $borrowers[$j]{$kee} =~ s/\"/'/g;
         if ($borrowers[$j]{$kee} =~ /,/){
            print $out '"'.$borrowers[$j]{$kee}.'",';
            next;
         }
         else{
            print $out $borrowers[$j]{$kee};
         }
      }
      print $out ",";
   }
   print $out "\n";
}
close $in;
close $out;
exit;

