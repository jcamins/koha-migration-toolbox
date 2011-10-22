#!/usr/bin/perl

# Sets patrons messaging preferences to default values
# Takes in an optional 'where' clause to limit borrowers (only that table is consulted)


# possible modules to use
use Getopt::Long;
use C4::Context;
use C4::Members::Messaging;

# Benchmarking variables
my $startime = time();
my $usecount = 0;
my $testmode;
my $whereclause;

GetOptions(
  't'	=> \$testmode,
  'where:s' => \$whereclause
);

my $dbh = C4::Context->dbh;

if (defined $whereclause) {$whereclause = " WHERE $whereclause";}

my $sth = $dbh->prepare(  "SELECT borrowernumber, categorycode FROM borrowers".$whereclause);
$sth->execute();
while (@row = $sth->fetchrow_array()){
  my $borrowernumber= $row[0];
  my $categorycode = $row[1];

  C4::Members::Messaging::SetMessagingPreferencesFromDefaults( { borrowernumber => $borrowernumber, 
                                                                categorycode   => $categorycode } ) unless (defined $testmode);
  # increment for benchmarking
  $usecount++;

  # report on progress
  print "$borrowernumber ($categorycode) set to defaults\n" if (defined $testmode);
}

# Benchmarking
my $endtime = time();
my $time = $endtime-$startime;
print "Total of $usecount records modified in $time seconds\n";
