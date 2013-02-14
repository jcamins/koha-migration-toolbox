#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -Joy Nelson
#
#---------------------------------
#
# EXPECTS:
#   -input CSV in this form:
#      <borrwer_cardnumber>
#
# DOES:
#   -updates the borrowers message preferences based on their category code,
#         if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of items modified

use strict;
use warnings;
 
use C4::Context;
use C4::Members::Messaging;
use Getopt::Long;
use Text::CSV;
    
$|=1;
my $debug = 0;
my $doo_eet = 0;
my $i=0;
my $written=0;
my $infile_name = q{};

GetOptions(
       'in:s'   => \$infile_name,
	   'debug'    => \$debug,
	   'update'   => \$doo_eet,
);

if (($infile_name eq q{})) {
   print "Something's missing.\n";
   exit;
}

my $csv=Text::CSV_XS->new();
my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare("SELECT borrowernumber, categorycode FROM borrowers WHERE cardnumber = ?");
open my $infl,"<",$infile_name;

RECORD:
while (my $line=$csv->getline($infl)){
  last RECORD if ($debug and $i>10);
  $i++;
  print "." unless ($i % 10);
  print "\r$i" unless ($i % 100);
  my @data = @$line;
  $sth->execute($data[0]);
  my $hash=$sth->fetchrow_hashref();
  my $borr_number = $hash->{'borrowernumber'};
  my $borr_cat = $hash->{'categorycode'};
  
  if ($doo_eet) {
     print "$borr_number: $borr_cat\n";
     C4::Members::Messaging::SetMessagingPreferencesFromDefaults( {
           borrowernumber => $borr_number,
           categorycode   => $borr_cat,
           } );
       }
	 $written++;
}
    
print "\n\n$i records read.\n$written items updated.\n";
   

