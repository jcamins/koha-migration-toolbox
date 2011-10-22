#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use C4::Context;
use C4::Members;

$|=1;
my $debug=0;
my $doo_eet=0;
my $date = ""; 

GetOptions(
    'date=s'  => \$date,
    'debug'   => \$debug,
    'update'  => \$doo_eet,
);

if ($date eq ""){
   print "Something's missing.\n";
   exit;
}

my $i=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT borrowernumber FROM borrowers 
                       WHERE dateexpiry < ? AND 
                       borrowernumber NOT IN (SELECT borrowernumber FROM issues) AND
                       borrowernumber NOT IN (SELECT borrowernumber FROM reserves) AND
                       borrowernumber NOT IN (SELECT borrowernumber FROM accountlines) AND
                       borrowernumber NOT IN 
                         (SELECT guarantorid FROM borrowers WHERE guarantorid IS NOT NULL AND guarantorid <> 0)");
$sth->execute($date);
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "deleting borrower $row->{'borrowernumber'}\n";
   if ($doo_eet){
      DelMember($row->{'borrowernumber'});
   }
}
 
print "\n\n$i records droppped.\n";
