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
my $debug = 0;

GetOptions(
    'in=s'     => \$infile_name,
    'out=s'    => \$outfile_name,
    'resp=s'   => \$respfile_name,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($respfile_name eq '')){
   print "You're missing something.\n";
   exit;
}

my $csv = Text::CSV->new({ binary => 1,eol => "\015\012" });

open INFL,"<$infile_name";
open OUTFL,">$outfile_name";
open RESPFL,">$respfile_name";
my $i=0;
my @borrowers;
my %headerkees;
my @branches = qw/0 QUIN CHES GREN PORT ALLE DOWN 0 LOYA SIER/;
my $headerline = $csv->getline(INFL);
my @fields = @$headerline;
while (my $row=$csv->getline(INFL)){
   my @data=@$row;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   exit if ($debug and $i>10);
   my %thisborrower;
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
      if ($fields[$j] eq "Class"){
         $thisborrower{'categorycode'} = $data[$j];
         $thisborrower{'categorycode'} = "ST" if ($data[$j] eq "STAFF");
         $thisborrower{'categorycode'} = "NO_SVC" if ($data[$j] eq "NO SERVICE");
         $headerkees{'categorycode'} = 1; 
      }
      if ($fields[$j] eq "Note"){
         $thisborrower{'borrowernotes'} = $data[$j];
         $headerkees{'borrowernotes'} = 1;
      }
      if ($fields[$j] eq "Barcode #"){
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
      if ($fields[$j] eq "Responsible Party" && ($data[$j] ne "")){
         $thisborrower{'guarantorbarcode'}=$data[$j];
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
      if ($fields[$j] eq "Branch of last activity"){
         $thisborrower{'branchcode'} = $branches[$data[$j]]; 
         $thisborrower{'branchcode'} = "QUIN" if (!$thisborrower{'branchcode'} || $thisborrower{'branchcode'} eq '0');
         $headerkees{'branchcode'} = 1; 
      }
      if ($fields[$j] eq "Blocked" && $data[$j] eq "Blocked") {
         $thisborrower{'debarred'} = 1;
         $headerkees{'debarred'} = 1; 
      }
   }
   if (!$thisborrower{'barcode'}){
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
   if ($borrowers[$j]{'guarantorbarcode'}){
      print RESPFL $borrowers[$j]{'cardnumber'}.",".$borrowers[$j]{'guarantorbarcode'}."\n";
   }
}
close INFL;
close OUTFL;
close RESPFL;
