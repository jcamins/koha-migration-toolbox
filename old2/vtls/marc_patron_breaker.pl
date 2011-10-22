#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# This script is intended to ingest a MARC-formatted patron file from 
# VTLS Virtua, and write an output file in a form that can be 
# fed to ByWater's General Purpose Database Table Loader script.
#
# -D Ruth Bavousett
#
#---------------------------------

use Getopt::Long;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;


my $infile_name = "";
my $outfile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
    'out=s'    => \$outfile_name,
);

if (($infile_name eq '') || ($outfile_name eq '')){
    print << 'ENDUSAGE';

Usage:  marc_patron_breaker --in=<infile> --out=<outfile> --map=<mapfile>

<infile>     A MARC-formatted data file, from which you wish to extract data.

<outfile>    A pipe-delimted file to feed to the Data Table Loader.

ENDUSAGE
exit;
}

open OUTFL,">$outfile_name";
print OUTFL "cardnumber|";
print OUTFL "surname|";
print OUTFL "firstname|";
print OUTFL "address|";
print OUTFL "city|";
print OUTFL "zipcode|";
print OUTFL "country|";
print OUTFL "email|";
print OUTFL "phone|";
print OUTFL "branchcode|";
print OUTFL "categorycode|";
print OUTFL "dateenrolled|";
print OUTFL "dateexpiry|";
print OUTFL "borrowernotes\n";

my $fh = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$fh);
$batch->warnings_off();
$batch->strict_off();
my $i=0;
my %categories;
while () {
   my $record = $batch->next();
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);
   next if ($record->subfield("030","a") eq "HU");
   $i++;
   print ".";
   print "\r$i" unless $i % 100;

   # BARCODE

   if ($record->subfield("015","a")){ print OUTFL $record->subfield("015","a")."|"; }
   else { print OUTFL "AUTO".$i."|";}

   # NAME

   my $namestr = $record->subfield("100","a");
   my $surname,$firstname;
   if ($namestr =~ /,/){ 
      ($surname,$firstname) = split (/\,/ , $namestr); 
   }
   else {
      ($firstname,$surname) = split (/ / , $namestr);
   }
   $firstname =~ s/^ *//;
   $surname =~ s/^ *//;
   $firstname =~ s/ *$//;
   $surname =~ s/ *$//;
   $firstname =~ s/  / /g;
   $surname =~ s/  / /g;
   print OUTFL $surname."|".$firstname."|";

   # ADDRESS

   print OUTFL $record->subfield("270","a") if ($record->subfield("270","a") ne "local");
   print OUTFL "|";

   if (($record->subfield("270","b") =~ /CANADA/) || ($record->subfield("270","e") =~ /CANADA/)){
      print OUTFL "|";
      print OUTFL $record->subfield("270","f");
      print OUTFL "|CANADA|";
   }
   else{
      print OUTFL $record->subfield("270","b") if ($record->subfield("270","b") ne "local");
      print OUTFL ", ";
      print OUTFL $record->subfield("270","d") if ($record->subfield("270","d") ne "local");
      print OUTFL "|";
      print OUTFL $record->subfield("270","e") if ($record->subfield("270","e") ne "local");
      print OUTFL "||";
   }

   # EMAIL

   print OUTFL $record->subfield("271","a")."|";

   # PHONE

   my $phonestr = $record->subfield("270","k");
   $phonestr =~ s/\D//g;
   if (length($phonestr) == 10){
      $phonestr =~ s/(\d{3})(\d{3})(\d{4})/($1)$2-$3/;
   }
   elsif (length($phonestr) == 7){
      $phonestr =~ s/(\d{3})(\d{4})/$1-$2/;
   }
   print OUTFL $phonestr."|";

   # BRANCH AND CATEGORY
   
   print OUTFL "MAIN|"; 
   my $thiscat = $record->subfield("030","a");
   $thiscat = "ILL" if ($thiscat eq "IL");
   $thiscat = "COMM" if ($thiscat eq "CB");
   $categories{$thiscat}++; 
   print OUTFL $thiscat."|";

   # DATE ENROLLED
   
   my $dateenr = $record->subfield("042","a");
   $dateenr =~ s/(\d{4})(\d{2})(\d{2}).*/$1-$2-$3/;
   print OUTFL $dateenr."|";


   # DATE EXIPRING
   
   my $dateexp = $record->subfield("042","b");
   $dateexp =~ s/(\d{4})(\d{2})(\d{2}).*/$1-$2-$3/;
   print OUTFL $dateexp."|";

   # NOTES
 
   my $notestr = $record->subfield("500","a");
   $notestr =~ s/^.$//;
   $notestr =~ s///g;
   print OUTFL $notestr;

   print OUTFL "\n";
}
close OUTFL;

print "RESULTS BY CATEGORYCODE\n";
foreach my $kee (sort keys %categories){
   print $kee.":   ".$categories{$kee}."\n";
}

