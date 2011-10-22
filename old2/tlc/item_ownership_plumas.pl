#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Accounts;

my $infile_name = "";
my $branchcode = "";

GetOptions(
    'in=s'     => \$infile_name,
    'branch=s' => \$branchcode,
);

if (($infile_name eq "") || ($branchcode eq "")){
   print "You're missing stuff.\n";
   exit;
}

my $dbh= C4::Context::dbh();
my $sth= $dbh->prepare("SELECT itemnumber,biblionumber FROM items WHERE barcode=?");

open INFL,"<$infile_name";
my $csv=Text::CSV->new();
my $i=0;
my $head=$csv->getline(INFL);
my @fields=@$head;
while (my $row=$csv->getline(INFL)){
   my @data=@$row;

   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   $sth->execute($data[3]);
   my $itmrec=$sth->fetchrow_hashref();

   $data[8] =~ /(\d*)\/(\d*)\/(\d*)/;
   my ($mon,$day,$year) = (($1),($2),($3));
   $year += 2000 if ($year < 11);
   $year += 1900 if ($year < 100);
   my $dateout = sprintf "%04d-%02d-%02d",$year,$mon,$day;

   C4::Items::ModItem({homebranch => $branchcode,
                       holdingbranch => $branchcode,
                       datelastseen => $dateout,
                       issues => $data[9]
                      },$itmrec->{'biblionumber'},$itmrec->{'itemnumber'});
}
print "\n$i items edited.\n\n";
