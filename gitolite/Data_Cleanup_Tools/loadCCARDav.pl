#!/usr/bin/perl

# Populates an authorized value 'CCARD' with data in a CSV file
# Incoming data takes the format value, description, opac description
# Based on an outdated version of KohaModProto (update me!!!)

# possible modules to use
use C4::Context;
use C4::Items;
use C4::Biblio;
use C4::Members;

# Benchmarking variables
my $startime = time();
my $usecount = 0;

# input from file, output log
open(IN, "CCARD_CODES.csv") || die ("Cannot open input file");

# fetch info from IN file
while (<IN>){
  chomp();
  my @row = split(/,/);
  my $value = $row[0];
  my $descrip = $row[1];
  my $opac_descrip = $row[2];

  my $sth2  = $dbh->prepare ("INSERT INTO authorised_values (category, authorised_value, lib, lib_opac) VALUES ('CCARD', ?,?,?)");
  #$sth2->execute($value, $descrip, $opac_descrip);  

  # increment for benchmarking
  $usecount++;

  # report on progress
  print "Added line CCARD, $value, '$descrip', '$opac_descrip'\n";
}

# Benchmarking
my $endtime = time();
my $time = $endtime-$startime;
print "Total of $usecount records modified in $time seconds\n";
