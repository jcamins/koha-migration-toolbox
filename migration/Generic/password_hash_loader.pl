#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use warnings;
use strict;
use Getopt::Long;
use Text::CSV;
use C4::Context;
$|=1;

my $infile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
);

if (($infile_name eq '')){
   print "You're missing something.\n";
   exit;
}

my $csv=Text::CSV->new();
my $dbh=C4::Context->dbh();
my $i=0;
open my $io,"<$infile_name";
my $sth = $dbh->prepare("UPDATE borrowers SET password = ? WHERE cardnumber = ?");
while (my $row=$csv->getline($io)){
   my @data=@$row;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $sth->execute($data[1],$data[0]);
}

print "$i\n\n";
print "$i records loaded.\n";

