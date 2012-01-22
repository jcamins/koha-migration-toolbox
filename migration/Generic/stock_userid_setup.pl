#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Members;
$|=1;
my $debug=0;
my $doo_eet=0;

my $branch = "";
GetOptions(
    'branch:s'   => \$branch,
    'update'     => \$doo_eet,
    'debug'      => \$debug,
);

#if (($infile_name eq '')){
#   print "You're missing something.\n";
#   exit;
#}

my $dbh=C4::Context->dbh();
my $i=0;
my $written=0;
my $query = "SELECT borrowernumber,cardnumber,userid,branchcode FROM borrowers";
if ($branch ne q{}){
   $query .= " WHERE branchcode = '$branch'";
}

my $find = $dbh->prepare($query);
$find->execute();
RECORD:
while (my $row=$find->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "Changing $row->{'cardnumber'} ($row->{'branchcode'}) \n";
   next RECORD if ($row->{userid});
   $doo_eet and C4::Members::ModMember(borrowernumber => $row->{'borrowernumber'}, 
                                       userid         => $row->{'cardnumber'});
   $written++;
}

print "\n$i records reed.\n$written records updated.\n";
