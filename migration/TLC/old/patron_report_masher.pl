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
my $branch_map_name = "";
my %branch_map;
my $category_file_name = "";

GetOptions(
    'in=s'            => \$infile_name,
    'out=s'           => \$outfile_name,
    'branch_map=s'    => \$branch_map_name,
    'category=s'      => \$category_file_name,
    'debug'           => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($category_file_name eq '')){
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

my @borrower_fields = qw /cardnumber       surname       firstname    address
                         address2         city          zipcode      email
                         dateofbirth      branchcode    categorycode dateenrolled  
                         dateexpiry       debarred      password     userid/;

my $csv = Text::CSV->new();
my %category;
my $i=0;
print "Reading in borrower categories.\n";
open my $cats,"<",$category_file_name;
while (my $line = readline($cats)){
   $i++;
   print '.';
   print "\r$i" unless ($i % 100);
   chomp $line;
   my ($kee,$val) = split /,/, $line;
   $category{$kee} = $val;
}
print "\n$i patrons read in.\n";

open my $in,"<$infile_name";
open my $out,">",$outfile_name;
open my $resp,">","responsibilities.csv";
open my $notes,">","borr_notes.csv";

for my $t (0..scalar(@borrower_fields)-1){
   print $out $borrower_fields[$t].',';
}
         print {$out} "\n";

$i=0;
my $j=0;
my $k=0;
for (1..7){
   my $dum = readline($in);   #get past the header.
}
my %thisborr;
my %patron_branches;
my %patron_categories;
my $line_tick = 5;
RECORD:
while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;

   next RECORD if $data[1] eq "Borrower Listing by ID Range";
   next RECORD if $data[0] eq "Borrowers in ID range:";
   next RECORD if $data[1] eq "Registered by location:";
   next RECORD if $data[3] eq "Date last active";

   if ($data[1] ne ' ' && $data[5] ne q{} && $line_tick > 1){
      if ($thisborr{cardnumber}){               
         $thisborr{userid} = $thisborr{cardnumber};
         $thisborr{password} = substr $thisborr{cardnumber}, -4;
         $thisborr{categorycode} = $category{$thisborr{cardnumber}};
         $patron_categories{$thisborr{categorycode}}++;
         $patron_branches{$thisborr{branchcode}}++;
         for my $t (0..scalar(@borrower_fields)-1){
            if ($thisborr{$borrower_fields[$t]}){
               $thisborr{$borrower_fields[$t]} =~ s/\"/'/g;
               if ($thisborr{$borrower_fields[$t]} =~ /,/){
                  print $out '"'.$thisborr{$borrower_fields[$t]}.'"';
               }
               else{
                  print $out $thisborr{$borrower_fields[$t]};
               }
            }
            print $out ",";
         }
         print {$out} "\n";
         $j++;
      }
      %thisborr=();
      $data[0] =~ m/(.*)\W(\w+)$/;
      $thisborr{firstname} = $1;
      $thisborr{surname} = $2;
      $thisborr{cardnumber} = $data[1];
      $thisborr{dateexpiry} = _process_date($data[2]);
      if ($data[4] eq 'B'){
         $thisborr{debarred} = 1;
      }
      $line_tick=1;
      next RECORD;
   }

   if ($line_tick == 1){
      $thisborr{address} = $data[0];
      $thisborr{dateenrolled} = _process_date($data[2]);
      $line_tick = 2;
      next RECORD;
   }

   if ($line_tick == 2){
      $thisborr{address2} = $data[0];
      if ($data[0] =~ /(\w+), (\w{2})[.]?\s+([\d\-]+)/){
         $thisborr{city} = "$1, $2";
         $thisborr{zipcode} = $3;
         $thisborr{address2} = undef;
      }
      if ($data[1] ne "no resp party"){
         $data[1] =~ m/^(\d+) /;
         print {$resp} "$thisborr{cardnumber},$1\n";
      }
      if ($data[3] ne ' '){
         $thisborr{email} = $data[3];
      }
      $thisborr{dateofbirth} = _process_date($data[2]);
      $line_tick = 3;
      next RECORD;
   }

   if ($line_tick == 3){
      if ($data[0] =~ /(\w+), (\w\w)[.]?\s+([\d\-]+)/){
         $thisborr{city} = "$1, $2";
         $thisborr{zipcode} = $3;
      }
      elsif (!$thisborr{city}){
         $thisborr{city} = $data[0];
      }
      $line_tick = 4;
      next RECORD;
   }

   if ($line_tick == 4){
      $thisborr{branchcode} = $data[3];
      if (exists $branch_map{$data[3]}){
         $thisborr{branchcode} = $branch_map{$data[3]};
      }
   }
   
   next RECORD if $data[1] eq ' ';
   # otherwise, it's a notes line.
   print {$notes} "$thisborr{cardnumber},$data[1]\n";
}

close $in;
print "\n\n$i lines read.\n$j borrowers written.\n";
print "\nResults by branchcode:\n";
foreach my $kee (sort keys %patron_branches){
    print $kee.":  ".$patron_branches{$kee}."\n";
}
open my $sql,">patron_sql.sql";
print "\nResults by categorycode:\n";
foreach my $kee (sort keys %patron_categories){
    print $kee.":  ".$patron_categories{$kee}."\n";
    print $sql "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}
close $sql;

exit;

sub _process_date {
   my $datein= shift;
   return undef if ($datein eq q{});
   return undef if ($datein eq ' ');
   my ($month,$day,$year) = split /\//,$datein;
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}

