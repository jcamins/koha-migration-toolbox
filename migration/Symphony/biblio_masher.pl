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
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $branch = "";
my $branch_map_name = "";
my %branch_map;
my $shelfloc_map_name = "";
my %shelfloc_map;
my $itype_map_name = "";
my %itype_map;
my $collcode_map_name = "";
my %collcode_map;
my $callscheme_map_name = "";
my %callscheme_map;
my $drop_noitem = 0;
my $reverse_cats = 0;
my $locs_to_collcodes = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'branch=s'          => \$branch,
    'branch_map=s'      => \$branch_map_name,
    'shelfloc_map=s'    => \$shelfloc_map_name,
    'itype_map=s'       => \$itype_map_name,
    'callscheme_map=s'  => \$callscheme_map_name,
    'collcode_map=s'    => \$collcode_map_name,
    'locs_to_collcodes' => \$locs_to_collcodes,
    'drop_noitem'   => \$drop_noitem,
    'reverse_cats'  => \$reverse_cats,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
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
$debug and print Dumper(%collcode_map);
if ($callscheme_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$callscheme_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $callscheme_map{$data[0]} = $data[1];
   }
   close $mapfile;
}


my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
open my $outfl,">:utf8",$outfile_name;
my $i=0;
my $j=0;
my $written=0;
my $no_999=0;
my $bad_999=0;
my %branchcount;
my %itypecount;
my %loccount;
my %collcodecount;
my %itype_942count;
my %callschemecount;

while () {
   last if ($debug and $i > 99);
   my $record = $batch->next();
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);
   $i++;
   print "." unless $i % 10;
   print "\r$i" unless $i % 100;

   if (!$record->field("999")){
       $no_999++;
       next if ($drop_noitem);  
       foreach my $dumpfield($record->field('9..')){
          $record->delete_field($dumpfield) if (($dumpfield->tag() ne '945') && ($dumpfield->tag() ne '998'));
       }
       foreach my $dumpfield($record->field('852')){
          $record->delete_field($dumpfield);
       }
       print $outfl $record->as_usmarc();
       $written++;
       next;
   }
   
   my $price = 0;

   if ($record->subfield("350","a")){
      $price = $record->subfield("350","a");
      #$price =~ s/\D\.]//;
      $price =~ s/(\d+(\.[0-9]{2}))/$1/;
      $price =~ s/\$//g;
   }

   my %homebranch;
   my %holdbranch;
   my %itype;
   my %loc;
   my %collcode;
   my %acqdate;
   my %seendate;
   my %item_hidden_note;
   my %itmprice;
   my %replprice;
   my %copynum;
   my %itemcall;
   my %itemnote;
   my %issues;
   my %callscheme;
   my $keeper_itype;

   foreach my $field ($record->field("999")){
      $j++;
      if (!$field->subfield('i') || !$field->subfield('t')){
         $bad_999++;
         next;
      }
      my $barcode = $field->subfield('i');

      $itype{$barcode} = uc($field->subfield('t'));
      if (exists($itype_map{$itype{$barcode}})){
         $itype{$barcode} = $itype_map{$itype{$barcode}};
      }
      $itypecount{$itype{$barcode}}++;
      $keeper_itype=$itype{$barcode};
      $loc{$barcode} = uc($field->subfield('l'));
      $loc{$barcode} = "UNKNOWN" if (!$loc{$barcode});
      if (exists($shelfloc_map{$loc{$barcode}})){
         $loc{$barcode} = $shelfloc_map{$loc{$barcode}};
      }
      $loccount{$loc{$barcode}}++;
      $item_hidden_note{$barcode} = $field->subfield('o');
      $copynum{$barcode} = $field->subfield('c');
      $homebranch{$barcode} = $field->subfield('m');
      $homebranch{$barcode} = $branch if (!$homebranch{$barcode});
      if (exists($branch_map{$homebranch{$barcode}})){
         $homebranch{$barcode} = $branch_map{$homebranch{$barcode}};
      }
      $branchcount{$homebranch{$barcode}}++;
      $holdbranch{$barcode} = $homebranch{$barcode};
      $itemcall{$barcode} = $field->subfield('a');
      $issues{$barcode} = $field->subfield('n');
      
      if ($field->subfield('u')){
         my ($month,$day,$year) = split(/\//,$field->subfield('u'));
         if ($month && $day && $year){
            $acqdate{$barcode} = sprintf "%4d-%02d-%02d",$year,$month,$day;
         }
      }

      if ($field->subfield('d')){
         my ($month,$day,$year) = split(/\//,$field->subfield('d'));
         if ($month && $day && $year){
            $seendate{$barcode} = sprintf "%4d-%02d-%02d",$year,$month,$day;
         }
      }
      if ($field->subfield('w')){
         $callscheme{$barcode} = $field->subfield('w');
         if (exists($callscheme_map{$callscheme{$barcode}})){
            $callscheme{$barcode} = $callscheme_map{$callscheme{$barcode}};
         }
         $callschemecount{$callscheme{$barcode}}++ if ($callscheme{$barcode});
      }

      my $thisprice=0;
      if ($field->subfield('p')){
         $thisprice = $field->subfield('p');
         $thisprice =~ s/(\d+(\.[0-9]{2}))/$1/;
         $thisprice =~ s/\$//g;
      }
      if (!$thisprice){
         $itmprice{$barcode} = $price if ($price);
         $replprice{$barcode} = $price if ($price);
      }
      else {
         $itmprice{$barcode} = $thisprice;
         $replprice{$barcode} = $thisprice;
      }

      if ($locs_to_collcodes){
         if (exists($collcode_map{$loc{$barcode}})){
            $collcode{$barcode} = $collcode_map{$loc{$barcode}};
         }
      }
      else {
         my $cat1 = uc($field->subfield('x'));
         my $cat2 = uc($field->subfield('z'));
         if ($reverse_cats){
            $cat1 = uc($field->subfield('z'));
            $cat2 = uc($field->subfield('x'));
         }
         my $part1 = $cat1 ? substr($cat1,0,2) : "__";
         my $part2 = $cat2 ? substr($cat2,0,8) : "________";
         my $finalcode = $part1.$part2;
         $collcode{$barcode} = "";
         $collcode{$barcode} = $finalcode if ($finalcode ne "__________");
         if (exists($collcode_map{$collcode{$barcode}})){
            $collcode{$barcode} = $collcode_map{$collcode{$barcode}};
         }
      }
      $collcodecount{$collcode{$barcode}}++ if ($collcode{$barcode});
   }

   foreach my $dumpfield($record->field('9..')){
      $record->delete_field($dumpfield);
   }
   foreach my $dumpfield($record->field('852')){
      $record->delete_field($dumpfield);
   }
   if ($keeper_itype){
      my $tag942=MARC::Field->new("942"," "," ", "c" => $keeper_itype);
      $record->insert_grouped_field($tag942);
      $itype_942count{$keeper_itype}++;
   }

   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $holdbranch{$key},
        "c" => $loc{$key},
        "o" => $itemcall{$key},
        "y" => $itype{$key},
        "g" => $itmprice{$key},
        "v" => $replprice{$key},
        "2" => $callscheme{$key},
      );
      $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
      $itmtag->update( "r" => $seendate{$key} ) if ($seendate{$key});
      $itmtag->update( "x" => $item_hidden_note{$key} ) if ($item_hidden_note{$key});
      $itmtag->update( "8" => $collcode{$key} ) if ($collcode{$key});
      $itmtag->update( "t" => $copynum{$key} ) if ($copynum{$key});
      $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
      $itmtag->update( "l" => $issues{$key} ) if ($issues{$key});

      $record->insert_grouped_field($itmtag);
   }

   print $outfl $record->as_usmarc();
   $written++;
}
 

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_999 biblios with no 999.\n$bad_999 999s missing barcode or itemtype.\n";
open my $sql, ">biblio_sql.sql";
print "\nBRANCHES:\n";
foreach my $kee (sort keys %branchcount){
   print $kee.":   ".$branchcount{$kee}."\n";
   print $sql  "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itypecount){
   print $kee.":   ".$itypecount{$kee}."\n";
   print $sql "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','$kee');\n";

}
print "\nITEM TYPES (942):\n";
foreach my $kee (sort keys %itype_942count){
   print $kee.":   ".$itype_942count{$kee}."\n";
}
print "\nSHELVING LOCATIONS:\n";
foreach my $kee (sort keys %loccount){
   print $kee.":   ".$loccount{$kee}."\n";
   print $sql "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','$kee');\n";
}
print "\nCOLLECTION CODES\n";
foreach my $kee (sort keys %collcodecount){
   print $kee.":   ".$collcodecount{$kee}."\n";
   print $sql "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','$kee');\n";
}
print "\n";

