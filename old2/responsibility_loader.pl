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
use Getopt::Long;
use Text::CSV;
use C4::Context;

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
my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
my $sth = $dbh->prepare("UPDATE borrowers SET guarantorid = ? WHERE cardnumber = ?");
while (my $row=$csv->getline($io)){
   my @data=@$row;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $convertq->execute($data[1]);
   my $arr= $convertq->fetchrow_hashref();
   my $guarantor= $arr->{'borrowernumber'};
   $sth->execute($guarantor,$data[0]);
}

