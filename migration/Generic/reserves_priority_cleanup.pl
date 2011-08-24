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
use Text::CSV;
use C4::Context;
$|=1;

my $debug=0;
my $doo_eet=0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

#if (($infile_name eq '') || ($table_name eq '')){
#   print "Something's missing.\n";
#   exit;
#}

my $dbh=C4::Context->dbh();
my $i=0;
my $reserves_edited = 0;

my $biblio_sth = $dbh->prepare("SELECT distinct(biblionumber) from reserves order by biblionumber");
my $reserves_sth = $dbh->prepare("SELECT borrowernumber, reservedate, constrainttype FROM reserves
                                  WHERE  biblionumber   = ?
                                  AND ((found <> 'W') or found is NULL)
                                  AND (priority > 0 or priority IS NULL)
                                  ORDER BY reservedate,priority ASC");
my $upd_sth = $dbh->prepare("UPDATE reserves SET priority = ?
                             WHERE biblionumber = ? AND borrowernumber = ? AND reservedate = ? AND found IS NULL");
$biblio_sth->execute();
BIBLIO:
while (my $biblio = $biblio_sth->fetchrow_array ){
   $debug and last BIBLIO if $i > 0;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my @priority;
   $debug and print "Biblio : $biblio\n";
   $reserves_sth->execute($biblio);
   while ( my $line = $reserves_sth->fetchrow_hashref ) {
      push( @priority, $line );
   }
RESERVE:
   for (my $j = 0;$j < @priority;$j++) {
      $debug and print "Borrowernumber: $priority[$j]->{'borrowernumber'}   Date: $priority[$j]->{'reservedate'}\n";
      if ($doo_eet){
         $upd_sth->execute($j + 1, $biblio, $priority[$j]->{'borrowernumber'}, $priority[$j]->{'reservedate'});
      }
      $reserves_edited++;
   }
}

print "$i biblio records processed.  $reserves_edited reserves corrected.\n";
