#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use warnings;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Members;
$|=1;
$debug=0;
$doo_eet=0;

my $where_clause = '';

GetOptions(
    'update'     => \$doo_eet,
    'where=s'    => \$where_clause,
    'debug'      => \$debug,
);

#if (($infile_name eq '')){
#   print "You're missing something.\n";
#   exit;
#}

my $dbh=C4::Context->dbh();
my $i=0;
my $query = "SELECT borrowernumber,surname FROM borrowers";
if ($where_clause ne '') {
   $query .= ' WHERE '.$where_clause;
}
$debug and print "QUERY: $query\n";
my $find = $dbh->prepare($query);

$find->execute();
while (my $row=$find->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print "Changing $row->{'cardnumber'} to $row->{surname}\n" if ($debug);
   $doo_eet and C4::Members::ModMember(borrowernumber => $row->{'borrowernumber'}, 
                                       password       => $row->{'surname'}
                                      );
}

print "\n$i records updated.\n";
