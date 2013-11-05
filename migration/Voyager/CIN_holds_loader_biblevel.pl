#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -JEN 4/3/201
#   retooling of fines loader to handle holds
# -JEN 5/1/2012 
#   change to load holds at bib level
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Accounts;
use autodie;

$|=1;
my $debug=0;
my $doo_eet=0;

my $infile_name = "";
my $mapfile_name=q{};

GetOptions(
    'in=s'            => \$infile_name,
    'map=s'           => \$mapfile_name,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}
my $i=0;

my %bibnum_map;
if ($mapfile_name ne q{}) {
   my $csv=Text::CSV_XS->new();
   print "Reading map:\n";
   open my $data_file,'<',$mapfile_name;
   while (my $line = $csv->getline($data_file)) {
      $i++;
      print ".";
      print "\r$i" unless $i % 100;

      my @data = @$line;
      $bibnum_map{$data[0]} = $data[1];
   }
   close $data_file;
}

$i=0;
my %problem;
my %success;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO reserves (borrowernumber, biblionumber, reservedate, branchcode, priority, expirationdate, constrainttype)
        VALUES (?,?,?,?,?,?,?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $hold_sth = $dbh->prepare("SELECT biblionumber FROM reserves WHERE borrowernumber=?");
my $thisbibnum = "";

my $second_csv=Text::CSV_XS->new({binary => 1});
open my $in,'<',$infile_name;

MAINLOOP:
while (my $line = $second_csv->getline($in)){
   my @data = @$line;
   print ".";
   print "\r$i" unless $i % 100;

   my $thisbar = $data[1];

   $borr_sth->execute($thisbar);
   my $db_borr_fetch=$borr_sth->fetchrow_hashref();
   my $borrnum=$db_borr_fetch->{'borrowernumber'};

   my $borrbranch=$data[3];
   if (!$borrnum){
      $problem{'borrowers not found'}++;
      next MAINLOOP;
   }
   $thisbibnum = $data[0];
   if (exists $bibnum_map{$data[0]}) {
      $thisbibnum= $bibnum_map{$data[0]};
   }

   my $bibnum=$thisbibnum;
#   my $createdate = _process_date2($data[4]);
#   my $expiredate = _process_date2($data[5]);
   my $createdate = $data[4];
   my $expiredate = $data[5];

   my $priority= $data[2];

$hold_sth->execute($borrnum);
my $borrhold=$hold_sth->fetchrow_hashref();
my $borr_hold=$borrhold->{'biblionumber'};

if (($borr_hold) && ($borr_hold eq $bibnum)){
next MAINLOOP;
}
   $debug and print "bib: $bibnum borr: $data[1],$borrbranch, $createdate, $expiredate, $priority\n";

   if (($borrnum) && ($bibnum)){
      $doo_eet and $sth->execute($borrnum,$bibnum,$createdate,$borrbranch,$priority,$expiredate,"a");
      $success{'holds inserted'}++;
   }
   if (!$bibnum){
      print "Cannot load borrower: $data[1] bib_id: $data[0])\n";
      $success{'no bib number - could not load'}++;
   }
 
}
close $in;

print "\n\n$i lines read.\n";
foreach my $kee (sort keys %success){
   print "$success{$kee} $kee\n";
}
print "\nProblems:\n";
foreach my $kee (sort keys %problem){
   print "$problem{$kee} $kee\n";
}
   
exit;


sub _process_date2 {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq "";
   my ($month,$day,$year) = $datein =~ /(\d+).(\d+).(\d\d)/;
   $year = $year+2000;
   if ($month && $day && $year) {
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
   }
   else {
      return undef;
   }
}



sub _process_date {
   my $datein=shift;
   return undef if $datein eq q{};
   my %months =(
                  JAN => 1, FEB => 2,  MAR => 3,  APR => 4,
                  MAY => 5, JUN => 6,  JUL => 7,  AUG => 8,
                  SEP => 9, OCT => 10, NOV => 11, DEC => 12
               );
   my ($day,$monthstr,$year) = split /\-/, $datein;
   if ($year < 40){
       $year +=2000;
   }
   else{
       $year +=1900;
   }
   return sprintf "%4d-%02d-%02d",$year,$months{$monthstr},$day;
}
