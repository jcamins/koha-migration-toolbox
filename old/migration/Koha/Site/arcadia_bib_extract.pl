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
use C4::Biblio;
use C4::Items;
use C4::Members;

$|=1;
my $debug=0;

my $branch = "";
my $branch_map_name = "";
my %branch_map;
my $shelfloc_map_name = "";
my %shelfloc_map;
my $itype_map_name = "";
my %itype_map;
my $collcode_map_name = "";
my %collcode_map;
my $skip_biblio = 0;

GetOptions(
    'branch=s'          => \$branch,
    'branch_map=s'      => \$branch_map_name,
    'shelfloc_map=s'    => \$shelfloc_map_name,
    'itype_map=s'       => \$itype_map_name,
    'collcode_map=s'    => \$collcode_map_name,
    'debug'             => \$debug,
);

if (($branch eq '')){
  print "Something's missing.\n";
  exit;
}

if ($branch_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$branch_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($shelfloc_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$shelfloc_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $shelfloc_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($itype_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$itype_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $itype_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($collcode_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$collcode_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $collcode_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $dbh = C4::Context->dbh();

print "Dumping bibliographic records:\n";
open my $out,">:utf8","biblios_".$branch.".mrc";
my $pre = $dbh->prepare("SELECT DISTINCT biblionumber FROM items WHERE homebranch='$branch'");
if ($branch eq "ALL"){
   $pre = $dbh->prepare("SELECT DISTINCT biblionumber FROM items");
}
my $sth = $dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
$pre->execute();
my $i=0;
my %permlocs;
my %curlocs;
my %shelflocs;
my %itypes;
my %itype_942;
my %collcodes;

while (my $prerow = $pre->fetchrow_hashref()){
   #$debug and last if ($i > 5000);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $sth->execute($prerow->{'biblionumber'});
   my $row = $sth->fetchrow_hashref();
   my $marc = MARC::Record::new_from_usmarc($row->{'marc'});
   foreach my $field ($marc->field("942")){
      if ($field->subfield('c')){
      if (exists $itype_map{$field->subfield('c')}){
         $field->update( c => $itype_map{$field->subfield('c')});
      }
      $itype_942{$field->subfield('c')}++;
      }
   }
   my %homebranch;
   my %holdbranch;
   my %itype;
   my %loc;
   my %damaged;
   my %collcode;
   my %acqdate;
   my %acqsource;
   my %seendate;
   my %item_hidden_note;
   my %itmprice;
   my %replprice;
   my %copynum;
   my %itemcall;
   my %itemnote;
   my %issues;
   my %enumchron;
   my %controlnum;
   my %renews;
   my %holds;
   my %datedue;
   my %borrowdate;
   my %uri;
   my %pricedate;
   my %withdrawn;
   my %loststat;
   my %callsource;
   my %bound;
   my %restrict;
   my %notforloan;

TAG952:
   foreach my $field ($marc->field("952")){
      next TAG952 if !$field->subfield('y');
      next TAG952 if !$field->subfield('i');
      next TAG952 if !$field->subfield('t');
      my $barcode = $field->subfield('i');
      $homebranch{$barcode} = $field->subfield('y');
      if (exists $branch_map{$homebranch{$barcode}}){
         $homebranch{$barcode} = $branch_map{$homebranch{$barcode}};
      }
      $permlocs{$homebranch{$barcode}}++;

      $holdbranch{$barcode} = $field->subfield('m') || $homebranch{$barcode};
      if (exists $branch_map{$holdbranch{$barcode}}){
         $holdbranch{$barcode} = $branch_map{$holdbranch{$barcode}};
      }
      $curlocs{$holdbranch{$barcode}}++;

      $itype{$barcode} = $field->subfield('t');
      if (exists $itype_map{$itype{$barcode}}){
         $itype{$barcode} = $itype_map{$itype{$barcode}};
      }
      $itypes{$itype{$barcode}}++;
     
      $loc{$barcode} = $field->subfield('l');
      if ($loc{$barcode} && exists $shelfloc_map{$loc{$barcode}}){
         $loc{$barcode} = $shelfloc_map{$loc{$barcode}};
         $loc{$barcode} = undef if ($loc{$barcode} eq q{});
      }
      $shelflocs{$loc{$barcode}}++ if $loc{$barcode};

      $collcode{$barcode} = $field->subfield('8');
      if ($collcode{$barcode} && exists $collcode_map{$collcode{$barcode}}){
         $collcode{$barcode} = $collcode_map{$collcode{$barcode}};
         $collcode{$barcode} = undef if ($collcode{$barcode} eq q{});
      }
      $collcodes{$collcode{$barcode}}++ if $collcode{$barcode};

      $acqdate{$barcode} = $field->subfield('u');
      $acqsource{$barcode} = $field->subfield('b');
      $itmprice{$barcode}  = $field->subfield('p');
      $enumchron{$barcode} = $field->subfield('h');
      $controlnum{$barcode} = $field->subfield('j');
      $issues{$barcode}     = $field->subfield('r');
      $renews{$barcode}     = $field->subfield('s');
      $holds{$barcode}      = $field->subfield('v');
      $itemcall{$barcode}   = $field->subfield('a');
      $datedue{$barcode}    = $field->subfield('k');
      $seendate{$barcode}   = $field->subfield('d');
      $borrowdate{$barcode} = $field->subfield('e');
      $copynum{$barcode}    = $field->subfield('c');
      $uri{$barcode}        = $field->subfield('n');
      $replprice{$barcode}  = $field->subfield('g');
      $pricedate{$barcode}  = $field->subfield('w');
      $item_hidden_note{$barcode} = $field->subfield('x');
      $itemnote{$barcode}         = $field->subfield('z');
      $withdrawn{$barcode}        = $field->subfield('0');
      $loststat{$barcode}         = $field->subfield('1');
      $callsource{$barcode}       = $field->subfield('2');
      $bound{$barcode}            = $field->subfield('3');
      $damaged{$barcode}          = $field->subfield('4');
      $restrict{$barcode}         = $field->subfield('5');
      $notforloan{$barcode}       = $field->subfield('7');
   }   

   foreach my $dumpfield($marc->field('952')){
      $marc->delete_field($dumpfield);
   }

   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $holdbranch{$key},
        "y" => $itype{$key},
      );
      $itmtag->update( "c" => $loc{$key}              ) if ($loc{$key});
      $itmtag->update( "d" => $acqdate{$key}          ) if ($acqdate{$key});
      $itmtag->update( "e" => $acqsource{$key}        ) if ($acqsource{$key});
      $itmtag->update( "g" => $itmprice{$key}         ) if ($itmprice{$key});
      $itmtag->update( "h" => $enumchron{$key}        ) if ($enumchron{$key});
      $itmtag->update( "j" => $controlnum{$key}       ) if ($controlnum{$key});
      $itmtag->update( "l" => $issues{$key}           ) if ($issues{$key});
      $itmtag->update( "m" => $renews{$key}           ) if ($renews{$key});
      $itmtag->update( "n" => $holds{$key}            ) if ($holds{$key});
      $itmtag->update( "o" => $itemcall{$key}         ) if ($itemcall{$key});
      $itmtag->update( "q" => $datedue{$key}          ) if ($datedue{$key});
      $itmtag->update( "r" => $seendate{$key}         ) if ($seendate{$key});
      $itmtag->update( "s" => $borrowdate{$key}       ) if ($borrowdate{$key});
      $itmtag->update( "t" => $copynum{$key}          ) if ($copynum{$key});
      $itmtag->update( "u" => $uri{$key}              ) if ($uri{$key});
      $itmtag->update( "v" => $replprice{$key}        ) if ($replprice{$key});
      $itmtag->update( "w" => $pricedate{$key}        ) if ($pricedate{$key});
      $itmtag->update( "x" => $item_hidden_note{$key} ) if ($item_hidden_note{$key});
      $itmtag->update( "z" => $itemnote{$key}         ) if ($itemnote{$key});
      $itmtag->update( "0" => $withdrawn{$key}        ) if ($withdrawn{$key});
      $itmtag->update( "1" => $loststat{$key}         ) if ($loststat{$key});
      $itmtag->update( "2" => $callsource{$key}       ) if ($callsource{$key});
      $itmtag->update( "3" => $bound{$key}            ) if ($bound{$key});
      $itmtag->update( "4" => $damaged{$key}          ) if ($damaged{$key});
      $itmtag->update( "5" => $restrict{$key}         ) if ($restrict{$key});
      $itmtag->update( "7" => $notforloan{$key}       ) if ($notforloan{$key});
      $itmtag->update( "8" => $collcode{$key}         ) if ($collcode{$key});

      $marc->insert_grouped_field($itmtag);
   }
   print $out $marc->as_usmarc();
}
close $out;
open $out,">biblio_codes.sql";
print $out "# Branches \n";
foreach my $kee (sort keys %permlocs){
   print $out "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','NEW--$kee');\n";
}
foreach my $kee (sort keys %curlocs){
   print $out "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','NEW--$kee');\n" if (!$permlocs{$kee});
}
print $out "# Shelving Locations\n";
foreach my $kee (sort keys %shelflocs){
   print $out "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','NEW--$kee');\n";
}
print $out "# Item Types\n";
foreach my $kee (sort keys %itypes){
   print $out "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','NEW--$kee');\n";
}
foreach my $kee (sort keys %itype_942){
   print $out "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','NEW--$kee');\n" if (!$itypes{$kee});
}
print $out "# Collection Codes\n";
foreach my $kee (sort keys %collcodes){
   print $out "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','NEW--$kee');\n";
}
print "\n$i records written.\n";

print "\nHOME BRANCHES:\n";
foreach my $kee (sort keys %permlocs){
   print $kee.":   ".$permlocs{$kee}."\n";
}
print "\nHOLDING BRANCHES:\n";
foreach my $kee (sort keys %curlocs){
   print $kee.":   ".$curlocs{$kee}."\n";
}
print "\nSHELVING LOCATIONS:\n";
foreach my $kee (sort keys %shelflocs){
   print $kee.":   ".$shelflocs{$kee}."\n";
}
print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itypes){
   print $kee.":   ".$itypes{$kee}."\n";
}
print "\nITEM TYPES (942):\n";
foreach my $kee (sort keys %itype_942){
   print $kee.":   ".$itype_942{$kee}."\n";
}
print "\nCOLLECTION CODES\n";
foreach my $kee (sort keys %collcodes){
   print $kee.":   ".$collcodes{$kee}."\n";
}
print "\n";

exit;
