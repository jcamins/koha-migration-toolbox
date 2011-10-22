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
use Encode;
use Getopt::Long;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $sqlfile_name = "";
my $fixed_branch = "";
my $mapfile_name = "";
my %patron_cat_map;
my $drop_code_str = "";
my %drop_codes;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$mapfile_name,
    'sql=s'         => \$sqlfile_name,
    'branch=s'      => \$fixed_branch,
    'drop_codes=s'  => \$drop_code_str,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
if ($drop_code_str){
   foreach my $code (split(/,/,$drop_code_str)){
      $drop_codes{$code} = 1;
   }
}

if ($mapfile_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$mapfile_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $patron_cat_map{$data[0]} = $data[1];
   }
   close $mapfile;
}


open my $infl,"<$infile_name" || die ('problem opening $infile_name');
my $i=0;
my $written=0;

my $headerrow = readline($infl);
chomp $headerrow;
$headerrow = decode_utf8($headerrow);
my @fields = split(/\t/,$headerrow);
$debug and warn Dumper(@fields);
my %borrowers;
my %categories;
my %headerkees;
while (my $row=readline($infl)) {
   last if ($debug and $i == 1000);
   chomp $row;
   $row = decode_utf8($row);
   $row =~ s/\"//g;
   my @data=split (/\t/, $row);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $drop_this_borrower=0;
   next if (!$data[0]);
   $debug and print "$data[0]\n";
   my $barcode = $data[0];
   $barcode =~ s/ //g;
   for (my $j=1;$j<scalar(@data);$j++){
      $debug and print "$fields[$j]:  $data[$j]\n";
      $data[$j] =~ s/ $//g;
   }
   if (!$borrowers{$barcode}{'surname'}){
      $borrowers{$barcode}{'surname'} = $data[1];
      $headerkees{'surname'} = 1;
      $borrowers{$barcode}{'firstname'} = $data[3]." ".$data[2];
      $borrowers{$barcode}{'firstname'} =~ s/ $//g;
      $headerkees{'firstname'} = 1;
      if ($drop_codes{$data[4]}){
         $drop_this_borrower=1;
      }
      if ($patron_cat_map{$data[4]}){
         $data[4] = $patron_cat_map{$data[4]};
      }
      $borrowers{$barcode}{'categorycode'} = $data[4];
      $categories{$data[4]}++;
      $headerkees{'categorycode'} = 1;
      $borrowers{$barcode}{'dateofbirth'} = substr($data[5],0,10);
      $headerkees{'dateofbirth'} = 1;
      $borrowers{$barcode}{'dateenrolled'} = substr($data[6],0,10);
      $headerkees{'dateenrolled'} = 1;
      $borrowers{$barcode}{'dateexpiry'} = substr($data[7],0,10);
      $headerkees{'dateexpiry'} = 1;
      $borrowers{$barcode}{'borrowernotes'} = $data[8];
      $headerkees{'borrowernotes'} = 1;
      $borrowers{$barcode}{'address'} = $data[9];
      $headerkees{'address'} = 1;
      $borrowers{$barcode}{'city'} = $data[10].", ".$data[11];
      $headerkees{'city'} = 1;
      $borrowers{$barcode}{'zipcode'} = $data[12];
      $headerkees{'zipcode'} = 1;
      $borrowers{$barcode}{'phone'} = $data[13];
      $headerkees{'phone'} = 1;
      $borrowers{$barcode}{'branchcode'} = $data[17];
      if ($fixed_branch){
         $borrowers{$barcode}{'branchcode'} = $fixed_branch;
      }
      $headerkees{'branchcode'} = 1;
      $borrowers{$barcode}{'email'} = $data[18];
      $headerkees{'email'} = 1;
   }
   if ($data[14] eq "Responsible Party"){
      $borrowers{$barcode}{'borrowernotes'} .= " -- " if ($borrowers{$barcode}{'borrowernotes'} ne "");
      $borrowers{$barcode}{'borrowernotes'} .= "Responsible Party: ".$data[16]; 
      $headerkees{'borrowernotes'} = 1;
   }
   if ($drop_this_borrower){
      $borrowers{$barcode} = undef;
   }
}

$debug and warn Dumper(%borrowers);

close $infl;

open my $out,">:utf8",$outfile_name;
print $out "cardnumber,";
foreach my $kee (sort keys %headerkees){
   print $out $kee.",";
}
print $out "\n";
foreach my $bar (sort keys %borrowers){
   if ($borrowers{$bar}{'categorycode'}){
      print $out $bar.",";
      foreach my $kee (sort keys %headerkees){
         my $this = $borrowers{$bar}{$kee} || "";
         $this = '"'.$this.'"' if ($this =~ /,/);
         print $out $this.",";
      }
      print $out "\n";
      $written++;
   }
}

close $out;

print "\n\n$i lines read.\n$written borrowers written.\n";
print "Results by categorycode:\n";
foreach my $kee (sort keys %categories){
    print $kee.":  ".$categories{$kee}."\n";
}

if ($sqlfile_name){
   open my $sql,">$sqlfile_name";
   foreach my $kee (sort keys %categories){
      print $sql "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
   }
   close $sql;
}
