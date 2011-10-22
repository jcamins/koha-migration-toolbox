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

my $infile_name = "";
my $outfile_name = "";
my $respfile_name = "";
my $debug = 0;

GetOptions(
    'in=s'     => \$infile_name,
    'out=s'    => \$outfile_name,
    'resp=s'   => \$respfile_name,
);

if (($infile_name eq '') || ($outfile_name eq '')){
    print << 'ENDUSAGE';

Usage:  patron_reformatter --in=<infile> --out=<outfile> --resp=<respfile>

<infile>     A csv data file, from which you wish to extract data.

<outfile>   A csv output file, for cleaned MARC records.

<respfile>   A csv for responsibility data, to be loaded separately. 

ENDUSAGE
exit;
}

my $csv = Text::CSV->new();

open INFL,"<$infile_name";
open OUTFL,">$outfile_name";
open RESPFL,">$respfile_name";
my $i=0;
my @borrowers;
my %headerkees;
my $headerline = readline(INFL);
chomp $headerline;
my @fields = split (/,/,$headerline);
while (my $row=$csv->getline(INFL)){
   my @data=@$row;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my %thisborrower;
   for (my $j=0;$j<scalar(@data);$j++){
      $data[$j] =~ s/\"//g;
      $data[$j] =~ s/ $//g;
      if ($fields[$j] eq "Issuing Location"){
         $thisborrower{'branchcode'} = "DE";
         $thisborrower{'branchcode'} = "SMITH" if ($data[$j] eq "Smith River");
         $headerkees{'branchcode'} = 1; 
      }
      if ($fields[$j] eq "Expiration Date"){
         my ($mon,$day,$year) = split (/\//,substr($data[$j],0,10));
         $thisborrower{'dateexpiry'} = sprintf "%4d-%02d-%02d",$year,$mon,$day;
         $headerkees{'dateexpiry'} = 1; 
      }
      if ($fields[$j] eq "Date of Birth" && $data[$j]){
         my ($mon,$day,$year) = split (/\//,substr($data[$j],0,10));
         $thisborrower{'dateofbirth'} = sprintf "%4d-%02d-%02d",$year,$mon,$day;
         $headerkees{'dateofbirth'} = 1; 
      }
      if ($fields[$j] eq "Email Address"){
         $thisborrower{'email'} = $data[$j];
         $headerkees{'email'} = 1; 
      }
      if ($fields[$j] eq "Borrower Type Desc"){
         $thisborrower{'categorycode'} = "ADULT";
         $thisborrower{'categorycode'} = "CIC" if $data[$j] eq "After-school program cards w/o parent ID -- one book limit";
         $thisborrower{'categorycode'} = "ST" if ($data[$j] eq "Bindery shelf / Lost; unable to locate");
         $thisborrower{'categorycode'} = "MM" if ($data[$j] eq "Brookings Area");
         $thisborrower{'categorycode'} = "" if ($data[$j] eq "California outside NSCLS");
         $thisborrower{'categorycode'} = "CI" if ($data[$j] eq "City Resident");
         $thisborrower{'categorycode'} = "CN" if ($data[$j] eq "County Resident");
         $thisborrower{'categorycode'} = "" if ($data[$j] eq "Friends to shut-ins");
         $thisborrower{'categorycode'} = "Y" if ($data[$j] eq "Interlibrary Loan");
         $thisborrower{'categorycode'} = "ST" if ($data[$j] =~ "Mending");
         $thisborrower{'categorycode'} = "N" if ($data[$j] eq "New borrower O.T.F.");
         $thisborrower{'categorycode'} = "PO" if ($data[$j] eq "NSCLS Cardholder");
         $thisborrower{'categorycode'} = "" if ($data[$j] eq "Old borrower O.T.F.");
         $thisborrower{'categorycode'} = "X" if ($data[$j] eq "Overdue resp. parent");
         $thisborrower{'categorycode'} = "" if ($data[$j] eq "Relocated out of state");
         $thisborrower{'categorycode'} = "ST" if ($data[$j] eq "Staff");
         $thisborrower{'categorycode'} = "NR" if ($data[$j] eq "Temporary / non-resident");
         $thisborrower{'categorycode'} = "VOL" if ($data[$j] eq "Volunteer Account with Grace Period");
         $thisborrower{'categorycode'} = "" if ($data[$j] eq "WB\@EVHS");
         $thisborrower{'categorycode'} = "" if ($data[$j] eq "WB\@FCC");
         $thisborrower{'categorycode'} = "" if ($data[$j] eq "Wonder Bus");
         $headerkees{'categorycode'} = 1; 
      }
      if ($fields[$j] eq "Block Status" && $data[$j]) {
         $thisborrower{'debarred'} = 1;
         $headerkees{'debarred'} = 1; 
      }
      if ($fields[$j] eq "Barcode"){
         $thisborrower{'cardnumber'} = $data[$j];
         $headerkees{'cardnumber'} = 1;
      }
      if ($fields[$j] eq "Alternate ID" && $data[$j]){
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
         ($thisborrower{'guarantorbarcode'},undef)=split(/ /,$data[$j]);
      }
      if ($fields[$j] eq "Name"){
         $data[$j] =~ /(.*) (.*)$/; 
         $thisborrower{'surname'} = ($2);
         $thisborrower{'firstname'} = ($1);
         if ($data[$j] =~ /\,/) {
            $data[$j] =~ /(.*) (.*)\,(.*)$/;
            $thisborrower{'surname'} = ($2)." ".($3);
            $thisborrower{'firstname'} = ($1);
         }
         if(!$thisborrower{'surname'}){
            $thisborrower{'surname'} = $data[$j];
            $thisborrower{'firstname'} = "NOFIRSTNAME";
         } 
         $headerkees{'surname'} = 1; 
         $headerkees{'firstname'} = 1; 
      }
      if ($fields[$j] eq "Primary Line1"){
         $thisborrower{'address'} = $data[$j];
         $headerkees{'address'} = 1;
      }
      if ($fields[$j] eq "Primary City"){
         $thisborrower{'city'} = $data[$j];
         $headerkees{'city'} = 1;
      }
      if ($fields[$j] eq "Primary State"){
         $thisborrower{'state'} = $data[$j];
      }
      if ($fields[$j] eq "Primary ZIP"){
         $thisborrower{'zipcode'} = $data[$j];
         $headerkees{'zipcode'} = 1;
      }
      if ($fields[$j] eq "Primary Phone 1"){
         $thisborrower{'phone'} = $data[$j];
         $headerkees{'phone'} = 1;
      }
   }
   if ($thisborrower{'categorycode'} ne ""){
      push @borrowers,{%thisborrower};
   }
}
foreach my $kee (sort keys %headerkees){
   print OUTFL $kee.",";
}
print OUTFL "\n";
for (my $j=0;$j<scalar(@borrowers);$j++){
   foreach my $kee (sort keys %headerkees){
      if ($kee eq "city"){
         print OUTFL '"'.$borrowers[$j]{'city'}.", ".$borrowers[$j]{'state'}.'",';
         next;
      }
      if ($kee eq "address"){
         print OUTFL '"'.$borrowers[$j]{'address'}.'",';
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
 
      
        

