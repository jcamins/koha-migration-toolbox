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
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;

my $infile_name = "";


GetOptions(
    'in=s'     => \$infile_name,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq '')){
   print "Something's missing.\n";
   exit;
}

my $csv=Text::CSV->new();
open my $io,"<$infile_name";
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber FROM items WHERE barcode=? AND (datelastborrowed IS NULL or datelastborrowed='0000-00-00')");
my $i=0;
my $written=0;
while (my $line=$csv->getline($io)){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my @data = @$line;
   $sth->execute($data[0]);
   my $itmrec=$sth->fetchrow_hashref();
   next if (!$itmrec || !$data[1]);
   my ($month,$day,$year) = split (/\//,$data[1]);
   $year += 2000 if ($year < 12);
   $year += 1900 if ($year < 100);
   my $dateout = sprintf "%4d-%02d-%02d",$year,$month,$day; 
   $debug and print "Barcode: $data[0]  Itemnum: $itmrec->{'itemnumber'}  Dateout: $dateout\n";
   $doo_eet and C4::Items::ModItem({datelastborrowed => $dateout},undef,$itmrec->{'itemnumber'});
   $written++;
}

print "\n\n$i records read.$written items modified.\n";
