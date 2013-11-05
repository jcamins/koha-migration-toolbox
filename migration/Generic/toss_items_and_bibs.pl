#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -J Nelson
#    modification to look for other items on bib record
#    if found, leave bib, if none, delete bib
#---------------------------------
#
# EXPECTS:
#   -WHERE clause for select
#
# DOES:
#   -deletes the items, if --update is set
#   -checks bib record for other items.  
#     if items found, leaves bib
#     if no items found, deletes bib
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of items dumped
#   -details of what will be deleted, if --debug is set

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Items;
$|=1;
my $debug = 0;
my $doo_eet = 0;
my $i=0;

my $where_clause    = q{};

GetOptions(
   'where:s'  => \$where_clause,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if ($where_clause eq q{}){
   print "Something's missing.\n";
   exit;
}

my $written=0;
my $deleted_bib=0;

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT biblionumber,itemnumber FROM items WHERE $where_clause");
my $items_sth=$dbh->prepare("SELECT itemnumber FROM items where biblionumber = ?");
$sth->execute();
RECORD:
while (my $row=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $i>10);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);

   $debug and print "$row->{itemnumber} will be tossed.\n";
   my $bib_num=$row->{'biblionumber'};

   if ($doo_eet){
      DelItem($dbh,$row->{biblionumber},$row->{itemnumber});
      $written++;
   }

#   check for items on bib
   $items_sth->execute($bib_num);
   my $rec=$items_sth->fetchrow_hashref();
   
   if ((!$rec) && ($doo_eet)){
      C4::Biblio::DelBiblio($bib_num);
      $deleted_bib++
   }
}

print "\n\n$i records read.\n$written items tossed.\n$deleted_bib bibs deleted.\n";
