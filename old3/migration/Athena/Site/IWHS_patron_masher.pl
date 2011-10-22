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
my $cat_year_map_name = "";
my %birthdate_hash;
my $branch = "";

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$patron_cat_mapfile,
    'cat_year_map=s' => \$cat_year_map_name,
    'debug'         => \$debug,
    'branch=s'      => \$branch,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($branch eq '')){
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

my $csv = Text::CSV->new();
open my $in,"<$infile_name";

my $i=0;
my $j=0;
my %profiles;
my $headerline = $csv->getline($in);
my @fields = @$headerline;
my @borrowers;
my %headerkees;
my %categories;

while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my %thisborrower;
   $thisborrower{'branchcode'} = $branch;
   for (my $j=0;$j<scalar(@data);$j++){
      if ($fields[$j] =~ /^PATRONID/ ){
         $thisborrower{'cardnumber'} = $data[$j];
         if (length $data[$j] >= 4){
            $thisborrower{'password'} = substr $data[$j],-4;
         }
         else{
            $thisborrower{'password'} = $data[$j];
         }
      }

      # Names
      if ($fields[$j] =~ /^SURNAME/ ){
         $thisborrower{'surname'} = $data[$j];
      }
      if ($fields[$j] =~ /^FIRSTNAME/ ){
         $thisborrower{'firstname'} = $data[$j];
      }
   
      # Dates
      if ($fields[$j] =~ /^RECORDDATE/ ){
         $thisborrower{'dateenrolled'} = _process_date($data[$j]);
      }
      if ($fields[$j] =~ /^EXPIRYDATE/ ){
         $thisborrower{'dateexpiry'} = _process_date($data[$j]);
      }

      # Category/Birthdate
      if ($fields[$j] =~ /^GROUP1/ ){
         if ($data[$j] eq ""){
            $debug and warn "empty catcode!";
            $thisborrower{'categorycode'} = "UNKNOWN";
            next;
         }
         if (exists $patron_cat_map{$data[$j]}){
            $debug and warn "Swapping cat $data[$j] to $patron_cat_map{$data[$j]}.";
            $thisborrower{'categorycode'} = $patron_cat_map{$data[$j]};
            next;
         } 
         else {
            $thisborrower{'categorycode'} = uc $data[$j];
         }
      }
      if ($fields[$j] =~ /^GROUP2/ ){
         $thisborrower{'sort1'}= $data[$j];
      } 

      # Addresses
      if ($fields[$j] =~ /^STREET1/ ){
         $thisborrower{'address'} = $data[$j];
      }
      if ($fields[$j] =~ /^STREET2/ ){
         $thisborrower{'address2'} = $data[$j];
      }
      if ($fields[$j] =~ /^CITY/ ){
         $thisborrower{'city'} = $data[$j];
      }
      if ($fields[$j] =~ /^PROVSTATE/ && $data[$j] ne ""){
         $thisborrower{'city'} .= ", ".$data[$j];
      }
      if ($fields[$j] =~ /^POSTALZIP/ ){
         $thisborrower{'zipcode'} = $data[$j];
      }
      if ($fields[$j] =~ /^PHONE,/ ){
         $thisborrower{'phone'} = $data[$j];
      }
      if ($fields[$j] =~ /^PHONE2/ ){
         $thisborrower{'phonepro'} = $data[$j];
      }
      if ($fields[$j] =~ /^EMAIL/ ){
         $thisborrower{'email'} = $data[$j];
         $data[$j] =~ /(\w+)@/;
         $thisborrower{'userid'} = $1;
     }
      if ($fields[$j] =~ /^ASTREET1/ ){
         $thisborrower{'B_address'} = $data[$j];
      }
      if ($fields[$j] =~ /^ASTREET2/ ){
         $thisborrower{'B_address2'} = $data[$j];
      }
      if ($fields[$j] =~ /^ACITY/ ){
         $thisborrower{'B_city'} = $data[$j];
      }
      if ($fields[$j] =~ /^APROVSTATE/ && $data[$j] ne ""){
         $thisborrower{'B_city'} .= ", ".$data[$j];
      }
      if ($fields[$j] =~ /^APOSTALZIP/ ){
         $thisborrower{'B_zipcode'} = $data[$j];
      }
      if ($fields[$j] =~ /^APHONE,/ ){
         $thisborrower{'B_phone'} = $data[$j];
      }
      #if ($fields[$j] =~ /^AEMAIL/ ){
      #   $thisborrower{'B_email'} = $data[$j];
      #}

      # Notes
      if ((($fields[$j] =~ /^MESSAGE/ ) || ($fields[$j] =~ /^OTHER/ ) || ($fields[$j] =~ /^BLOCKMSG/ )) && $data[$j] ne ""){
         if ($thisborrower{'borrowernotes'}){
            $thisborrower{'borrowernotes'} .= " -- ".$data[$j];
         }
         else{
            $thisborrower{'borrowernotes'} = $data[$j];
         }
      }
      if ($fields[$j] =~ /^BLOCKMSG/ && $data[$j] ne ""){
         $thisborrower{'debarred'} = 1;
      }
   }
   push @borrowers,{%thisborrower};
   foreach my $kee (sort keys %thisborrower){
      $headerkees{$kee} = 1;
   }
}
print "\n\n$i lines read.\n";

open my $out,">$outfile_name";
foreach my $kee (sort keys %headerkees){
   print $out $kee.",";
}
print $out "\n";
for (my $j=0;$j<scalar(@borrowers);$j++){
   $categories{$borrowers[$j]{'categorycode'}}++;
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

open $out,">patron_codes.sql";
print $out "# Patron Categories\n";
foreach my $kee (sort keys %categories){
   print $out "INSERT INTO categories (categorycode,description) VALUES ('$kee','NEW--$kee');\n";
}
close $out;
print "\nPATRON CATEGORIES:\n";
foreach my $kee (sort keys %categories){
   print $kee.":   ".$categories{$kee}."\n";
}
exit;

sub _process_date {
   my $datein= shift;
   return "" if ($datein eq "");
   my ($month,$day,$year) = split(/\//,$datein);
   if ($year <=40){ 
      $year += 2000;
   }
   else {
      $year += 1900;
   }
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
