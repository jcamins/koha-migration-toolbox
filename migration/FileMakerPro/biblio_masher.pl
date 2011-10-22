#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
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
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
use Text::CSV_XS;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $branch_map_name = "";
my %branch_map;
my $itype_map_name = "";
my %itype_map;
my $loc_map_name = "";
my %loc_map;
my $collcode_map_name = "";
my %collcode_map;
my $default_branch = "";
my $default_itype = "";
my $drop_noitem = 0;


GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'branch_map=s'  => \$branch_map_name,
    'itype_map=s'   => \$itype_map_name,
    'loc_map=s'     => \$loc_map_name,
    'collcode_map=s' => \$collcode_map_name,
    'def_branch=s'  => \$default_branch,
    'def_itype=s'   => \$default_itype,
    'drop_noitem'   => \$drop_noitem,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $mapcsv = Text::CSV_XS->new({binary=> 1});

if ($branch_map_name ne q{}){
   open my $mapfile,"<$branch_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $branch_map{$data[0]}=$data[1];
   }
   close $mapfile;
}

if ($itype_map_name ne q{}){
   open my $mapfile,"<$itype_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $itype_map{$data[0]}=$data[1];
   }
   close $mapfile;
}

if ($loc_map_name ne q{}){
   open my $mapfile,"<$loc_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $loc_map{$data[0]}=$data[1];
   }
   close $mapfile;
}
$debug and print Dumper(%loc_map);

if ($collcode_map_name ne q{}){
   open my $mapfile,"<$collcode_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $collcode_map{$data[0]}=$data[1];
   }
   close $mapfile;
}

my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
#my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
open my $outfl,">",$outfile_name || die ('Cannot open outfile!');
my $i=0;
my $j=0;
my $written=0;
my %branch_counts;
my %itype_counts;
my %loc_counts;
my %collcode_counts;

RECORD:
while () {
   last RECORD if ($debug and $i > 20);
   my $record = $batch->next();
   if ($@){
      print "Bogusness skipped\n";
      next RECORD;
   }
   last unless ($record);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;

   my %homebranch;
   my %holdbranch;
   my %itype;
   my %loc;
   my %collcode;
   my %itmprice;
   my %replprice;
   my %itemcall;
   my %itemnote;
   my %enumchron;
   my %acqdate;
   my %issues;
   my %holds;
   my %renews;
   my %lastseen;
   my %lastborrowed;
   my %copynum;
   my %loststat;
   my %damstat;
   my %notforloanstat;

ITMFIELD:
   foreach my $field ($record->field("952")){
      $j++;

      my $barcode = $field->subfield('p');
      $itype{$barcode} = $field->subfield('y') || $default_itype;
      $loc{$barcode} = $field->subfield('c') || "";
      $itemcall{$barcode} = $field->subfield('o') || "";
      $collcode{$barcode} = $field->subfield('8') || "";

      if (exists $itype_map{$itype{$barcode}}){
         $itype{$barcode} = $itype_map{$itype{$barcode}};
      } 
      $itype_counts{$itype{$barcode}}++;
      
      if (exists $loc_map{$loc{$barcode}}){
         $loc{$barcode} = $loc_map{$loc{$barcode}};
      }
      $loc{$barcode} = undef if ($loc{$barcode} eq q{});
      $loc_counts{$loc{$barcode}}++ if $loc{$barcode};

      if (exists $collcode_map{$collcode{$barcode}}){
         $collcode{$barcode} = $collcode_map{$collcode{$barcode}};
      }
      $collcode{$barcode} = undef if ($collcode{$barcode} eq q{});
      $collcode_counts{$collcode{$barcode}}++ if $collcode{$barcode};

      $homebranch{$barcode} = $field->subfield('a') || "";
      if ( exists $branch_map{$homebranch{$barcode}}){
         $homebranch{$barcode} = $branch_map{$homebranch{$barcode}};
      }
      if ($homebranch{$barcode} eq q{}){
         $homebranch{$barcode} = $default_branch;
      }
      $holdbranch{$barcode} = $homebranch{$barcode};
      $branch_counts{$homebranch{$barcode}}++;

      $itmprice{$barcode} = 0;
      $replprice{$barcode} = 0;

   }

   foreach my $dumpfield($record->field('9..')){
      $record->delete_field($dumpfield);
   }

   my $write_this=0; 
   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $holdbranch{$key},
        "o" => $itemcall{$key},
        "y" => $itype{$key},
        "g" => $itmprice{$key},
        "v" => $replprice{$key},
        "2" => "lcc",
      );
      $itmtag->update( "c" => $loc{$key} )       if ($loc{$key});
      $itmtag->update( "8" => $collcode{$key} )  if ($collcode{$key});

      $record->insert_grouped_field($itmtag);
      $write_this = 1;
   }
   if (!$drop_noitem){
      $write_this = 1;
   }

   if ($write_this){
      #$debug and print $record->encoding();
      #$record->encoding ('utf-8');
      my $rec = $record->as_usmarc();
      #$rec = MARC::Charset::marc8_to_utf8($rec);
      print $outfl $rec;
      $written++;
   }
}
 
close $infl;
close $outfl;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n";
open my $sqlfl,">item_sql.sql";
print "BRANCH COUNTS\n";
foreach my $kee (sort keys %branch_counts){
   print "$kee:  $branch_counts{$kee}\n";
   print $sqlfl "INSERT INTO branches (branchcode,branchname) VALUES('$kee','$kee');\n";
}
print "\nITEM TYPE COUNTS\n";
foreach my $kee (sort keys %itype_counts){
   print "$kee:  $itype_counts{$kee}\n";
   print $sqlfl "INSERT INTO itemtypes (itemtype,description) VALUES('$kee','$kee');\n";
}
print "\nLOCATION COUNTS\n";
foreach my $kee (sort keys %loc_counts){
   print "$kee:  $loc_counts{$kee}\n";
   print $sqlfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES('LOC','$kee','$kee');\n";
}
print "\nCOLLECTION CODE COUNTS\n";
foreach my $kee (sort keys %collcode_counts){
   print "$kee:  $collcode_counts{$kee}\n";
   print $sqlfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES('CCODE','$kee','$kee');\n";
}
close $sqlfl;

