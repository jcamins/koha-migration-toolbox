#!/usr/bin/perl
#
# Joy Nelson
#
# DOES:
#  delete bibs/items based on icoming csv file of ebrary numbers
#  these are stored in 035$a tag/subfield in marc
#  script compares substring of 035$a to the csv file
#  
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of biblios considered
#   -count of biblios modified

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;
use C4::Items;

$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;
my $in_file ="";
my %data;
my @data;
my $data;
my %ebooks;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
    'file:s'      => \$in_file,);

if ($in_file eq q{}){
   print "Something's missing.\n";
   exit;
   }

my $csv = Text::CSV_XS->new();
my $written = 0;
my $dbh = C4::Context->dbh();

open my $infl,"<",$in_file;

while (my $line=$csv->getline($infl)){
  @data = @$line;
  $ebooks{$data[0]}=1;
}
close $infl;

my $deleted=0;
my $itemdel=0;

my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE biblionumber=?");

my $tags = 0;
my $modified = 0;

#Read the database, and if an 035$a is present and that substring of 035a is in the csv
#find the items, delete the items and delete the bib record.

my $sth = $dbh->prepare("SELECT biblionumber from biblio");
$sth->execute();

RECORD:
while (my $row = $sth->fetchrow_hashref()){
  last RECORD if ($debug and $written > 0);
  $i++;
  print '.' unless ($i % 10);
  print "\r$i" unless ($i % 100);

  my $record = GetMarcBiblio($row->{'biblionumber'});
  my $bibnum = $row->{'biblionumber'};
print "$bibnum\n";
  next RECORD if (!$record->field('001'));

  my $ctrltag = ($record->field('001') || "");
  my $tag = $ctrltag->data();

#$debug and print "$tag\n";
  my $final_tag = substr($tag,3) if (length($tag) > 0);
#$debug and print "$final_tag\n";

  if ($final_tag) {
   if ((exists $ebooks{$final_tag}) && $doo_eet){
     $item_sth->execute($bibnum);
$debug and print "$bibnum\n";
     my $db_item_fetch=$item_sth->fetchrow_hashref();
     my $itemnum=$db_item_fetch->{'itemnumber'};
     if (!$itemnum) {
     print "\n items not found for bib $bibnum \n";
     next;
     }
     if ($doo_eet){
         C4::Items::DelItem($dbh, $bibnum, $itemnum);
         $itemdel++;
         C4::Biblio::DelBiblio($bibnum);
         print "\n DELETED ebrary: $final_tag with bibnumber $bibnum \n";
         $deleted++;
     }
   }
 }
}

print "\n$itemdel items deleted\n$deleted bib records deleted.\n";


