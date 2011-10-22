#!/usr/bin/perl

# Resets all patron's expiration dates
# Takes in a base-line date, or uses Aug 15, 2009 as a default
# Computes the expiration date for the patron type

# TODO:  Add an optional 'where' clause to filter patrons

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
my $date = '2009-08-15';

GetOptions(
  't'	=> \$testmode,
  'date:s' => \$date
);

my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare(  "SELECT borrowernumber, categorycode FROM borrowers");
$sth->execute();
while (@row = $sth->fetchrow_array()){

  my $borrowernumber = $row[0];
  my $categorycode = $row[1];

  my $dateexpiry = GetExpiryDate($categorycode, $date);
  
  my $sth2 = $dbh->prepare("UPDATE borrowers SET dateexpiry = ? WHERE borrowernumber = ?");
  $sth2->execute($dateexpiry, $borrowernumber) unless (defined $testmode);  

  # increment for benchmarking
  $usecount++;

  # report on progress
  print "$borrowernumber : $dateexpiry\n";
}

# Benchmarking
my $endtime = time();
my $time = $endtime-$startime;
print "Total of $usecount records modified in $time seconds\n";
