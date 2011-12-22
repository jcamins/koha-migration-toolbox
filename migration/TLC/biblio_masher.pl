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
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $mapfile_name = "";
my $codes_filename = q{};
my $drop_noitem = 0;
my $dump_types_str="";
my %dump_types;


GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'drop_types=s'  => \$dump_types_str,
    'map=s'         => \$mapfile_name,
    'codesfile=s'   => \$codes_filename,
    'debug'         => \$debug,
    'drop_noitem'   => \$drop_noitem,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($mapfile_name eq '') || ($codes_filename eq q{})){
  print "Something's missing.\n";
  exit;
}

if ($dump_types_str){
   foreach my $typ (split(/,/,$dump_types_str)){
      $dump_types{$typ}=1;
   }
}

print "Reading in holding code map.\n";
my $mapcount = 0;
my %branchmap;
my %typemap;
my %locmap;
my %collmap;
my $mapcsv = Text::CSV->new();
open my $mapfile,"<$mapfile_name";
while (my $row = $mapcsv->getline($mapfile)){
   my @data = @$row;
   $mapcount++;
   print "." unless ($mapcount % 10);
   print "\r$mapcount" unless ($mapcount % 100);
   $branchmap{$data[0]}=$data[1];
   $typemap{$data[0]}=$data[2];
   $locmap{$data[0]}=$data[3];
   $collmap{$data[0]}=$data[4];
}
print "\n$mapcount lines read.\n\n";

print "Reading in holding codes:\n";
$mapcount = 0;
my %holdingcodes;
open $mapfile,"<",$codes_filename;
while (my $row = $mapcsv->getline($mapfile)) {
   my @data = @$row;
   $mapcount++;
   print '.'   unless ($mapcount % 10);
   print "\r$mapcount" unless ($mapcount % 100);
   $holdingcodes{$data[0]} = $data[1];
}
print "\n$mapcount lines read.\n";
print "Processing biblios.\n";

my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
open my $outfl,">:utf8",$outfile_name || die ('Cannot open outfile!');
my $i=0;
my $j=0;
my $written=0;
my $no_852=0;
my $bad_852=0;
my $drop_type=0;
my %branch_counts;
my %itype_counts;
my %loc_counts;
my %ccode_counts;
my %unmapped_codes;

while () {
   last if ($debug and $i > 99);
   my $record;
   eval{ $record = $batch->next(); };
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);
   $i++;
   print "." unless $i % 10;
   print "\r$i" unless $i % 100;

   if (!$record->field("852")){
       $no_852++;
       next if ($drop_noitem);  
       foreach my $dumpfield($record->field('9..')){
          $record->delete_field($dumpfield);
       }
       print $outfl $record->as_usmarc();
       $written++;
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

   foreach my $field ($record->field("852")){
      $j++;
      if (!$field->subfield('p') || !$field->subfield('a')){
         $bad_852++;
         next;
      }
      if ($dump_types{uc($field->subfield('a'))}){
         $drop_type++;
         next;
      }
      my $barcode = $field->subfield('p');
      my $holdcode = $holdingcodes{$barcode} || '';
      if ($holdcode eq q{}) {
         $holdcode = $field->subfield('a');
      }
      if ($branchmap{$holdcode}){
         $homebranch{$barcode} = $branchmap{$holdcode};
         $holdbranch{$barcode} = $branchmap{$holdcode};
         $itype{$barcode} = $typemap{$holdcode};
         $loc{$barcode}      = $locmap{$holdcode};
         $collcode{$barcode} = $collmap{$holdcode};
      }
      else{
         $unmapped_codes{$holdcode}++;
         $homebranch{$barcode} = "UNKNOWN";
         $itype{$barcode} = "UNKNOWN";
         $loc{$barcode} = q{};
         $collcode{$barcode} = q{};
      }
      $loc{$barcode} = undef if $loc{$barcode} eq q{};
      $collcode{$barcode} = undef if $collcode{$barcode} eq q{};

      $branch_counts{$homebranch{$barcode}}++;
      $itype_counts{$itype{$barcode}}++;
      $loc_counts{$loc{$barcode}}++ if $loc{$barcode};
      $ccode_counts{$collcode{$barcode}}++ if $collcode{$barcode};

      my $thisprice=0;
      if ($field->subfield('9')){
         $thisprice = $field->subfield('9');
         $thisprice =~ s/(\d+(\.[0-9]{2}))/$1/;
         $thisprice =~ s/\$//g;
      }
      if ($field->subfield('1')){
         $thisprice = $field->subfield('1');
         $thisprice =~ s/(\d+(\.[0-9]{2}))/$1/;
         $thisprice =~ s/\$//g;
         $thisprice += 10;
      }

      if (!$thisprice){
         $itmprice{$barcode} = $price if ($price);
         $replprice{$barcode} = $price if ($price);
      }
      else {
         $itmprice{$barcode} = $thisprice;
         $replprice{$barcode} = $thisprice;
      }

      $itemcall{$barcode} = $field->subfield('g') || "";
      if ($field->subfield('h')){
         $itemcall{$barcode} .= " "if $itemcall{$barcode};
         $itemcall{$barcode} .= $field->subfield('h');
      }
      if ($field->subfield('d')){
         $itemcall{$barcode} .= " "if $itemcall{$barcode};
         $itemcall{$barcode} .= $field->subfield('d');
      }
      if ($field->subfield('D')){
         $itemcall{$barcode} .= " "if $itemcall{$barcode};
         $itemcall{$barcode} .= $field->subfield('D');
      }
      if ($field->subfield('s')){
         $itemcall{$barcode} .= " "if $itemcall{$barcode};
         $itemcall{$barcode} .= $field->subfield('s');
      }

      $copynum{$barcode} = $field->subfield('c');
      if ($copynum{$barcode}){
         $copynum{$barcode} =~ s/[cC\.]//g;
      }

      $item_hidden_note{$barcode} = $field->subfield('7');

      if ($field->subfield('i')){
         $enumchron{$barcode} = $field->subfield('i');
      }

      if ($field->subfield('j')){
         $enumchron{$barcode} = $field->subfield('j');
      }

      if ($field->subfield('k')){
         $enumchron{$barcode} .= ' '. $field->subfield('k');
      }

      if ($field->subfield('y')){
         $enumchron{$barcode} .= ' '. $field->subfield('y');
      }

      if ($field->subfield('o')){
         $enumchron{$barcode} = $field->subfield('o');
      }

      if ($field->subfield('q')){
         $item_hidden_note{$barcode} .= " " if $item_hidden_note{$barcode};
         $item_hidden_note{$barcode} .= $field->subfield('q');
         $damaged{$barcode} = 1;
      }
      $acqsource{$barcode} = $field->subfield('x');
      
#      if ($field->subfield('d')){
#         if ($field->subfield('d') =~ m{(\d*)[-/](\d*)}){
#            my ($month,$year) = ($1,$2);
#            $year += 2000 if ($year < 12);
#            $year += 1900 if ($year <100);
#            $acqdate{$barcode} = sprintf "%4d-%02d-01",$year,$month;
#         }
#      }

   }

   foreach my $dumpfield($record->field('9..')){
      $record->delete_field($dumpfield);
   }
   foreach my $dumpfield($record->field('852')){
      $record->delete_field($dumpfield);
   }
 
   my $write_this = 0;
   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $holdbranch{$key},
        "o" => $itemcall{$key},
        "y" => $itype{$key},
        "g" => $itmprice{$key},
        "v" => $replprice{$key},
        "2" => "ddc",
      );
      $itmtag->update( "c" => $loc{$key} ) if ($loc{$key});
      $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
      $itmtag->update( "e" => $acqsource{$key} ) if ($acqsource{$key});
      $itmtag->update( "r" => $seendate{$key} ) if ($seendate{$key});
      $itmtag->update( "x" => $item_hidden_note{$key} ) if ($item_hidden_note{$key});
      $itmtag->update( "8" => $collcode{$key} ) if ($collcode{$key});
      $itmtag->update( "t" => $copynum{$key} ) if ($copynum{$key});
      $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
      $itmtag->update( "l" => $issues{$key} ) if ($issues{$key});
      $itmtag->update( "h" => $enumchron{$key} ) if ($enumchron{$key});
      $itmtag->update( "4" => $damaged{$key} ) if ($damaged{$key});
      

      $record->insert_grouped_field($itmtag);
      $write_this = 1;
   }
   if (!$drop_noitem){
      $write_this = 1;
   }

   if ($write_this){
      print $outfl $record->as_usmarc();
      $written++;
   }
}
 
close $infl;
close $outfl;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_852 biblios with no 852.\n$bad_852 852s missing barcode or holding code.\n";
print "$drop_type items dropped due to type.\n";
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
foreach my $kee (sort keys %ccode_counts){
   print "$kee:  $ccode_counts{$kee}\n";
   print $sqlfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES('CCODE','$kee','$kee');\n";
}
close $sqlfl;
print "\nUNMAPPED CODES\n";
foreach my $kee (sort keys %unmapped_codes){
   print "$kee:  $unmapped_codes{$kee}\n";
}

