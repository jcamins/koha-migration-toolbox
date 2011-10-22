#!/usr/bin/perl

# --------- INSERT DOCUMENTATION HERE ---------------#
# This prototype can be used to develop specific data manipulation scripts
# Input can be from a file or database query
# Output can be to a file or to screen

# possible modules to use
use Getopt::Long;
use C4::Context;
use C4::Items;
use C4::Biblio;
use C4::Members;

# Benchmarking variables
my $startime = time();
my $usecount = 0;
my $testmode;
my $filename;

GetOptions(
  't'	=> \$testmode,
  'f:s' => \$filename
);

# input from file, output log
open(IN, "$filename") || die ("Cannot open input file");
open(OUT, "#####") || die ("Cannot open report file");
my $dbh = C4::Context->dbh;

#------------------ USE THIS -------------------------#
# fetch records from DB
my $sth = $dbh->prepare(  "######SQL Query to get records to modify######");
$sth->execute(#####);
while (@row = $sth->fetchrow_array()){
#----------------OR USE THIS -------------------------#
# fetch info from IN file
while (<IN>){
  chomp();
  my @row = split(/,/);
#-----------------------------------------------------#
  my ###### = $row[0];
  my ###### = $row[1];
  my ###### = $row[2];
  my ###### = $row[3];

  #
  #  INSERT LOGIC
  #
 
  # Common changes to make
  ModItem({##### => #####, },$biblionumber,$itemnumber);
  C4::Members->ModMember(borrowernumber => $borrowernumber, ###### => ####);
  my $sth2  = $dbh->prepare ("#######");
  $sth2->execute(####) unless (defined $testmode);  

  # increment for benchmarking
  $usecount++;

  # report on progress
  print "########\n";
  print OUT "########\n";
}

# Benchmarking
my $endtime = time();
my $time = $endtime-$startime;
print "Total of $usecount records modified in $time seconds\n";
