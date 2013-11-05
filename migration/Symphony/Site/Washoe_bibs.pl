#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
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
#   -updates bibs/items to Washoe specs, if --update is specified
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is specified
#   -count of bibs/items modified

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
my $j       = 0;
my $written = 0;
my $problem = 0;


GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

#for my $var ($input_filename) {
#   croak ("You're missing something") if $var eq $NULL_STRING;
#}

my $dbh                  = C4::Context->dbh();
my $sth;
$i       = 0;
$sth     = $dbh->prepare("delete from issues where itemnumber in (select itemnumber from items where location='DISCARD')");
$sth->execute();

$i       = 0;
$sth     = $dbh->prepare("SELECT biblionumber,itemnumber FROM items WHERE location='DISCARD'");
$sth->execute();
while (my $item = $sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print "deleting item $item->{itemnumber}.\n";
   if ($doo_eet) {
      DelItem($dbh,$item->{biblionumber},$item->{itemnumber});
   }
}
 
print "\n\n"; 
print "$i records read and modified.\n";


$i = 0;
$j = 0;
$sth = $dbh->prepare("SELECT biblionumber FROM biblio WHERE title LIKE 'obituaries%'");
my %item = ( 'homebranch' => 'COMMRES',
             'holdingbranch' => 'COMMRES',
             'itype' => 'OBITS',
           );
$sth->execute();
while (my $bib = $sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $this_bib = $bib->{biblionumber};
   $item{barcode} = 'OBIT'.$this_bib;
   if ($doo_eet) {
      C4::Items::AddItem(\%item,$this_bib);
   }
   $j++;
}
print "\n\n";
print "$i records read.\n$j items added.\n";




open my $infl,'<','/home/load02/dropbox/items.data';
my $csv=Text::CSV_XS->new({binary => 1, sep_char => '|'});
$i   = 0;
$j   = 0;
my %new_type = ( 'DOWNAUD' => 'EAUDIO',
                 'EBSCOHOST' => 'EBSCOHOST',
                 'DOWNEBOOK' => 'EBOOK',
                 'INET_RSRSE' => 'GOVDOC',
               );
RECORD2:
while (my $line = $csv->getline($infl)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;
   next RECORD2 if ($data[2] ne 'ER');
   next RECORD2 if ($data[3] ne 'IR');
   next RECORD2 if (!exists $new_type{$data[5]});
   my $itemnum = C4::Items::GetItemnumberFromBarcode($data[1]);
   next RECORD2 if (!$itemnum);
   $debug and print "changing item $itemnum ($data[1]) to $new_type{$data[5]}\n";
   if ($doo_eet) {
      ModItem({ itype => $new_type{$data[5]} },undef,$itemnum);
   }
   $j++;
}
close $infl;
print "\n\n";
print "$i records read.\n$j records modified.\n";
    


exit;
