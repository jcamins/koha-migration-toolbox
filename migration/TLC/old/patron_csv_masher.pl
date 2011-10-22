#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use Getopt::Long;
use Text::CSV;
use Data::Dumper;

my $infile_name = "";
my $outfile_name = "";
my $respfile_name = "";
my $branch_map_name = "";
my %branch_map;
my $default_branch = "";
my $category_file_name = "";
my %category;
my $default_category = "";

my $debug = 0;
$|=1;

GetOptions(
    'in=s'     => \$infile_name,
    'out=s'    => \$outfile_name,
    'resp=s'   => \$respfile_name,
    'branch_map:s' => \$branch_map_name,
    'category=s'      => \$category_file_name,
    'default_category:s' => \$default_category,
    'default_branch:s' => \$default_branch,
    'debug'              => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($respfile_name eq '')){
   print "You're missing something.\n";
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


my $csv = Text::CSV->new({ binary => 1 });
my $i=0;
my $k=0;
print "Reading in borrower categories.\n";
open my $cats,"<",$category_file_name;
while (my $line = $csv->getline($cats)){
   $i++;
   print '.';
   print "\r$i" unless ($i % 100);
   my @data= @$line;
   $category{$data[0]} = $data[1];
}
print "\n$i patrons read in.\n";
close $cats;

open INFL,"<$infile_name";
open OUTFL,">$outfile_name";
open RESPFL,">$respfile_name";
$i=0;
my @borrowers;
my %branch_tally;
my %category_tally;
my %headerkees;
my $carryforward = "";
my $headerline = $csv->getline(INFL);
my @fields = @$headerline;
LINE:
while (my $row=$csv->getline(INFL)){
   my @data=@$row;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if (@data[2] eq q{}){
      $carryforward .= "\n".$data[0];
      next LINE;
   }
   exit if ($debug and $i>10);
   my %thisborrower;
   $debug and print "BEFORE:\n$data[0]\n";
   $data[0] = $carryforward."\n".$data[0];
   $debug and print "MID:\n$data[0]\n";
   $carryforward="";
   $data[0] =~ s/^\n//m;
   $debug and print "AFTER:\n$data[0]\n";
   for (my $j=0;$j<scalar(@data);$j++){
      $data[$j] =~ s/\"//g;
      $data[$j] =~ s/ $//g;
      if ($fields[$j] eq "Name"){
         my ($line1,$line2,$line3,$line4) = split(/\n/,$data[$j]);
         my $cityline="";
         if ($line4){
            $cityline = $line4;
         } elsif ($line3){  
            $cityline = $line3;
         }
         #
         # Name
         #
         $line1 =~ /(.*) (.*)$/; 
         $thisborrower{'surname'} = ($2);
         $thisborrower{'firstname'} = ($1);
         if ($line1 =~ /\,/) {
            $line1 =~ /(.*) (.*)\,(.*)$/;
            $thisborrower{'surname'} = ($2)." ".($3);
            $thisborrower{'firstname'} = ($1);
         }
         if(!$thisborrower{'surname'}){
            $thisborrower{'surname'} = $line1;
            $thisborrower{'firstname'} = "NOFIRSTNAME";
         } 
         $headerkees{'surname'} = 1; 
         $headerkees{'firstname'} = 1; 
         #
         # Address
         #
         if ($line2){
            $thisborrower{'address'} = $line2;
            $headerkees{'address'} = 1;
         }
         if ($line4){
            $thisborrower{'address2'} = $line3;
            $headerkees{'address2'} = 1;
         }
         #
         # City/State/Zip
         #
         if ($cityline){
            $cityline =~ /(.*)  (.*)$/;
            $thisborrower{'city'} = ($1);
            $headerkees{'city'} = 1;
            $thisborrower{'zipcode'} = ($2);
            $headerkees{'zipcode'} = 1;
         }
      }
#      if ($fields[$j] eq "Class"){
#         $thisborrower{'categorycode'} = $data[$j];
#         $thisborrower{'categorycode'} = "ST" if ($data[$j] eq "STAFF");
#         $thisborrower{'categorycode'} = "NO_SVC" if ($data[$j] eq "NO SERVICE");
#      }
      if ($fields[$j] eq "Note"){
         $thisborrower{'borrowernotes'} = $data[$j];
         $headerkees{'borrowernotes'} = 1;
      }
      if ($fields[$j] eq "ID #"){
         $thisborrower{'cardnumber'} = $data[$j];
         $headerkees{'cardnumber'} = 1;
      }
      if ($fields[$j] eq "Alternate ID #" && $data[$j]){
         if ($thisborrower{'patron_attributes'}){
           $thisborrower{'patron_attributes'} .= ",";
         }
         else {
           $thisborrower{'patron_attributes'} = "";
         }
         $thisborrower{'patron_attributes'} .= '"ALT ID:'.$data[$j].'"';
         $headerkees{'patron_attributes'} = 1;
      }
      if ($fields[$j] eq "Respparty" && ($data[$j] ne "no resp party")){
         ($thisborrower{'guarantorbarcode'},undef)=split(/ /,$data[$j]);
      }
      if ($fields[$j] eq "Card issue date"){
         $data[$j] =~ /(\d*)\/(\d*)\/(\d*)/;
         my ($mon,$day,$year) = (($1),($2),($3));
         $year += 2000 if ($year < 11);
         $year += 1900 if ($year < 100);
         $thisborrower{'dateenrolled'} = sprintf "%4d-%02d-%02d",$year,$mon,$day;
         $headerkees{'dateenrolled'} = 1; 
      }
      if ($fields[$j] eq "Card expiration date"){
         $data[$j] =~ /(\d*)\/(\d*)\/(\d*)/;
         my ($mon,$day,$year) = (($1),($2),($3));
         $year += 2000 if ($year < 11);
         $year += 1900 if ($year < 100);
         $thisborrower{'dateexpiry'} = sprintf "%4d-%02d-%02d",$year,$mon,$day;
         $headerkees{'dateexpiry'} = 1; 
      }
      if ($fields[$j] eq "Birthdate" && $data[$j]){
         $data[$j] =~ /(\d*)\/(\d*)\/(\d*)/;
         my ($mon,$day,$year) = (($1),($2),($3));
         $year += 2000 if ($year < 11);
         $year += 1900 if ($year < 100);
         $thisborrower{'dateofbirth'} = sprintf "%4d-%02d-%02d",$year,$mon,$day;
         $headerkees{'dateofbirth'} = 1; 
      }
      if ($fields[$j] eq "Email"){
         $thisborrower{'email'} = $data[$j];
         $headerkees{'email'} = 1; 
      }
      if ($fields[$j] eq "Registration branch"){
         $thisborrower{'branchcode'} = $branch_map{$data[$j]} || $default_branch."-".$data[$j]; 
         $headerkees{'branchcode'} = 1; 
      }
      if ($fields[$j] eq "Blocked status?" && $data[$j] eq "B") {
         $thisborrower{'debarred'} = 1;
         $headerkees{'debarred'} = 1; 
      }
   }
   $thisborrower{'categorycode'} = $category{$thisborrower{'cardnumber'}} || $default_category;
   $headerkees{'categorycode'} = 1; 
   $branch_tally{$thisborrower{'branchcode'}}++;
   $category_tally{$thisborrower{'categorycode'}}++;

   if ($thisborrower{'cardnumber'}){
      push @borrowers,{%thisborrower};
   }
}
foreach my $kee (sort keys %headerkees){
   print OUTFL $kee.",";
}
print OUTFL "\n";
for (my $j=0;$j<scalar(@borrowers);$j++){
   foreach my $kee (sort keys %headerkees){
      if (($kee eq "borrowernotes") || ($kee eq "address") || ($kee eq "address2") || ($kee eq "city")){
         print OUTFL '"'.$borrowers[$j]{$kee}.'",';
         next;
      }
      if ($borrowers[$j]{$kee}){
         print OUTFL $borrowers[$j]{$kee};
      }
      print OUTFL ",";
   }
   print OUTFL "\n";
   $k++;
   if ($borrowers[$j]{'guarantorbarcode'}){
      print RESPFL $borrowers[$j]{'cardnumber'}.",".$borrowers[$j]{'guarantorbarcode'}."\n";
   }
}
close INFL;
close OUTFL;
close RESPFL;

print "\n\n$i lines read.\n$k borrowers written.\n";

print "\nResults by branchcode:\n";
foreach my $kee (sort keys %branch_tally){
   print $kee.":  ".$branch_tally{$kee}."\n";
}
open my $sql,">patron_sql.sql";
print "\nResults by categorycode:\n";
foreach my $kee (sort keys %category_tally){
   print $kee.":  ".$category_tally{$kee}."\n";
   print $sql "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}
close $sql;

