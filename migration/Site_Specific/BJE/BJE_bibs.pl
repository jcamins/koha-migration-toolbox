#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -updates items, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would change, if --debug is set
#   -counts of modifications

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

use C4::Context;
use C4::Items;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $dbh = C4::Context->dbh();
my $sth;
my $grand_total = 0;
my $grand_total_written = 0;

print "\nSetting BJE Main Items:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode < 1000000 AND location IS NULL");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"MAIN", holdingbranch=>"MAIN"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting JCCSF:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode < 1000000 AND location='JCCSF'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"JCCSF", holdingbranch=>"JCCSF",location=>undef},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting JCCSF Pushcart:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode < 1000000 AND location='PUSHCART'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"MAIN", holdingbranch=>"JCCSF"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting JCCSF Storage:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode < 1000000 AND location='STORAGE'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"JCCSF", holdingbranch=>"JCCSF", location=>"STORAGE"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting Palo Alto:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode < 1000000 AND location='PALOALTO'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"PALOALTO", holdingbranch=>"PALOALTO",location=>undef},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting Palo Alto pushcart:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode < 1000000 AND location='PALOPUSH'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"MAIN", holdingbranch=>"PALOALTO",location=> undef},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting JCHS:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode > 999999");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"JCHS", holdingbranch=>"JCHS"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting CD:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'cd %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"CD"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting CD ref:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'cd ref%'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"CD REF",location=>"SEE",itemnotes=>"JCHS_ONLY"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting DVD:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'dvd %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"DVD"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting DVD Ref:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'dvd ref%'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"DVDREF",location=>"SEE",itemnotes=>"JCHS_ONLY"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting CASS:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'cass %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"CASS"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting DVDREF:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'dvdref %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"DVDREF",location=>"SEE",itemnotes=>"JCSH_ONLY"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting PERIODICALS:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'periodicals%'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"PERIODICAL"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting VHS:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'vhs %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"VHS"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting VIDEO:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'video %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"VHS"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting VIDEO REF:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'video ref%'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"VIDEO REF",location=>"SEE",itemnotes=>"JCHS_ONLY"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting REF:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'ref %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"REF"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting B-O-T\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'B-O-T %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"B-O-T"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting Book on CD:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'book on cd %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itype=>"BOOK ON CD"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location EDUC:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'EDUC %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"EDUC"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location GESHER:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'GESHER %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"LEARNHEBREW"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location LEKET:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'LEKET %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"LEARNHEBREW"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location LARGE TYPE:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'LARGE TYPE %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"LARGE"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location INTERFAITH:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'INTERFAITH %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"INTER"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location JB:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'JB %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"JB"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location RUSSIAN:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'RUSSIAN %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"RUSSIAN"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location JPIC:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'JPIC %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"JPIC"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location JPIC HEBREW:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'JPIC HEBREW %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"JUVHEBREW"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location J:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'J %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"JUV"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location JUV HEBREW:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE itemcallnumber LIKE 'J HEBREW %'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"JUVHEBREW"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting location 'f':\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE substring(itemcallnumber,1,2)='f '");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {location=>"OVERSIZE"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting JCHS_BOOK:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE homebranch='JCHS' and itype='BOOK'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {itemnotes=>"JCHS_BOOK"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting Book Club:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode < 1000000 AND location LIKE '%BOOKCLUB%'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"MAIN", holdingbranch=>"MAIN",itype=>"BOOK",itemnotes=>"BOOKCLUB",location=>"BOOKCLUB"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting Film Club:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode < 1000000 AND location LIKE '%FILMCLUB%'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"MAIN", holdingbranch=>"MAIN",itype=>"BOOK",itemnotes=>"FILMCLUB",location=>"FILMCLUB"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";

print "\nSetting Beit Midrash:\n";
$i=0;
$sth = $dbh->prepare("SELECT itemnumber FROM items WHERE location='BEIT'");
$sth->execute();
while (my $item=$sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "Setting $item->{itemnumber}.\n";
   if ($doo_eet) {
      C4::Items::ModItem( {homebranch=>"JCHS", holdingbranch=>"JCHS",location=>"BEIT"},undef,$item->{itemnumber} );
      $written++;
   }
}
$grand_total += $i;
$grand_total_written += $written;
print "\n$i records found.\n$written items modified.\n";



print "\n\nGrand totals:\n";
print "$grand_total records touched (some twice!).\n$grand_total_written items modified.\n";
exit;
