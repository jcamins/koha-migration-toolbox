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
my $breakpoint=0;

my $infile_name = "";
my $outfile_name = "";
my $mapfile_name = "";
my $itemfile_name = "";
my $drop_noitem = 0;
my $dump_types_str="";
my %dump_types;
my $use_hash=0;


GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'items=s'       => \$itemfile_name,
    'drop_types=s'  => \$dump_types_str,
    'map=s'         => \$mapfile_name,
    'use_hash'      => \$use_hash,
    'debug'         => \$debug,
    'drop_noitem'   => \$drop_noitem,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($mapfile_name eq '') || ($itemfile_name eq q{})){
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
my $mapcsv = Text::CSV_XS->new();
open my $mapfile,"<$mapfile_name";
while (my $row = $mapcsv->getline($mapfile)){
   my @data = @$row;
   $mapcount++;
   print ".";
   print "\r$mapcount" unless ($mapcount % 100);
   $branchmap{$data[0]}=$data[1];
   $typemap{$data[0]}=$data[2];
   $locmap{$data[0]}=$data[3];
}
print "\n$mapcount lines read.\n\n";

my %itmhash;
open my $out2,">","itemnum_to_barcode.csv";
if ($use_hash){
   my $itms = 0;
   print "Loading item data into memory.\n";
   open my $itmfl,"<$itemfile_name";
   while (my $itmline = readline($itmfl)){
      #$debug and last if ($itms > 24);
      $itms++;
      print ".";
      print "\r$itms" unless ($itms % 100);
      chomp $itmline;
      $itmline =~ s/^M//g;
      my $itmcsv = Text::CSV_XS->new( {binary => 1});
      $itmcsv->parse($itmline);
      my @data=$itmcsv->fields();
      my $bar=$data[22] || "";
      if ($bar ne q{}){
         push(@{$itmhash{$bar}}, $itmline);
         print {$out2} "$data[0],$bar\n"; 
      }
   }
   #$debug and warn Dumper(%itmhash);
   close $itmfl;
   print "\n$itms items loaded.\n\n";
}

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
my $bad_852_nobarcode=0;
my $bad_852_noholdcode=0;
my $drop_type=0;
my %branch_counts;
my %itype_counts;
my %loc_counts;
my %barcode_counts;

RECORD:
while () {
   last if ($debug and $i > 1);
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);

   my $biblionum=$record->subfield('998','a');

   if (!$record->field("852")){
       $no_852++;
       next RECORD if ($drop_noitem);  
       print $outfl $record->as_usmarc();
       $written++;
       next RECORD;
   }
   
   my $price = 0;

   if ($record->subfield("350","a")){
      $price = $record->subfield("350","a");
      $price =~ s/(\d+(\.[0-9]{2}))/$1/;
      $price =~ s/\$//g;
   }

   my %homebranch;
   my %holdbranch;
   my %itype;
   my %loc;
   my %itmprice;
   my %replprice;
   my %itemcall;
   my %itemnote;
   my %enumchron;
   my %materials;
   my %seendate;
   my %loans;
   my %renews;
   my %holds;
   my %lost;
   my %notforloan;

   foreach my $field ($record->field("852")){
      $j++;
      my $tempbarcode = "";
      my $copynum;
      if (!$field->subfield('p')){
         $bad_852_nobarcode++;
         my $copynum=$field->subfield('8');
         $copynum =~ s/\.//g;
         $tempbarcode = 'T-'.$biblionum .'-'.$copynum;
      }
      if (!$field->subfield('b')){
         $bad_852_noholdcode++;
         next;
      }
      if ($dump_types{uc($field->subfield('b'))}){
         $drop_type++;
         next;
      }
      my $barcode = $field->subfield('p') || $tempbarcode;
      my $orig_barcode = $barcode;
      if (exists $barcode_counts{$orig_barcode}){
         $barcode = $orig_barcode.'-'.$barcode_counts{$orig_barcode};
         $barcode_counts{$orig_barcode}++;
      }
      else{
         $barcode_counts{$orig_barcode}=1;
      }

      my $holdcode = $field->subfield('b');
      if ($branchmap{$holdcode}){
         $homebranch{$barcode} = $branchmap{$holdcode};
         $holdbranch{$barcode} = $branchmap{$holdcode};
         $itype{$barcode} = $typemap{$holdcode};
         $loc{$barcode} = $locmap{$holdcode};
         $branch_counts{$homebranch{$barcode}}++;
         $itype_counts{$itype{$barcode}}++;
         $loc_counts{$loc{$barcode}}++;
      }
      else{
         print "Trouble! $holdcode";
      }

      $itmprice{$barcode} = $price if ($price);
      $replprice{$barcode} = $price+25 if ($price);

      $itemcall{$barcode} = $field->subfield('h') || "";

      $enumchron{$barcode} = $field->subfield('y') || "";

      if ($field->subfield('v')){
         my $sub = $field->subfield('v');
         if ($sub =~ /^\d+$/mx){
            $enumchron{$barcode} .= " Vol. $sub";
         }
         else{
            $enumchron{$barcode} .= " $sub";
         }
      }

      if ($field->subfield('f')){
         $enumchron{$barcode} .= ' '. $field->subfield('f');
      }

      $enumchron{$barcode} =~ s/^\s+//;
      $enumchron{$barcode} = undef if ($enumchron{$barcode} eq q{});

      $itemnote{$barcode} = q{};

      if ($field->subfield('z')){
         $itemnote{$barcode} = $field->subfield('z');
      }

      my @matches;
   
      if ($tempbarcode ne q{}){
         @matches = qx{grep ",$biblionum," $itemfile_name;};
         #print Dumper (@matches);
      }
      else{
         if ($use_hash){
            foreach (@{$itmhash{$orig_barcode}}){
               push(@matches,$_);
            }
         }
         else{
            @matches = qx{grep ",$orig_barcode," $itemfile_name};
         }
      }

      foreach (@matches){
         my $match = $_;
         $debug and warn "$match";
         $match =~ s/[\x00-\x1f]//g;

         my $csv = Text::CSV_XS->new( {binary => 1});
         $csv->parse($match);
         my @data=$csv->fields();
         next if ($data[17] ne $biblionum);
         $debug and warn Dumper(@data);

         print {$out2} "$data[0],$barcode\n";

         if (scalar @data <38){
            print "\n$barcode has an item problem\n $match\n";
         }
         $materials{$barcode}=$data[1];
         if ($data[19] ne q{}){
            $itemnote{$barcode} = $data[19] . '--' .$itemnote{$barcode};
         }
         $itemnote{$barcode} =~ s/\-\-$//;
         if ($data[25] ne q{}){
            $itmprice{$barcode} = $data[25];
            $itmprice{$barcode} = $itmprice{$barcode}/100;
            $replprice{$barcode} = ($data[25]/100) + 25;
         }
         if ($data[3] eq "15"){ 
            $notforloan{$barcode} = 3;
         }
         if ($data[3] eq "10"){
            $lost{$barcode} = 4;
         }
         if ($data[5] ne q{}){
            my ($month,$day,$year) = split(/\//,$data[5]);
            $seendate{$barcode} = sprintf "%4d-%02d-%02d",$year,$month,$day; 
         }
         if ($data[7] ne q{}){
            $loans{$barcode} = $data[7];
         }
         if ($data[8] ne q{}){
            $renews{$barcode} = $data[8];
         }
         if ($data[9] ne q{}){
            $holds{$barcode} = $data[9];
         }
      }
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
        "2" => "lcc",
        "3" => $materials{$key},
      );
      $itmtag->update( "g" => $itmprice{$key} ) if ($itmprice{$key});
      $itmtag->update( "v" => $replprice{$key} ) if ($replprice{$key});
      $itmtag->update( "c" => $loc{$key} ) if ($loc{$key} ne q{});
      $itmtag->update( "r" => $seendate{$key} ) if $seendate{$key};
      $itmtag->update( "l" => $loans{$key} ) if $loans{$key};
      $itmtag->update( "m" => $renews{$key} ) if $renews{$key};
      $itmtag->update( "n" => $holds{$key} ) if $holds{$key};
      $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key} ne q{});
      $itmtag->update( "h" => $enumchron{$key} ) if ($enumchron{$key});
      $itmtag->update( "1" => $lost{$key} ) if ($lost{$key});
      $itmtag->update( "7" => $notforloan{$key} ) if ($notforloan{$key});

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

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_852 biblios with no 852.\n$bad_852_nobarcode 852s missing barcode.\n$bad_852_noholdcode 852s missing holding code.\n";
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
close $sqlfl;
open my $multifl,">multi_barcode_counts.csv";
foreach my $kee (sort keys %barcode_counts){
   if ($barcode_counts{$kee} > 1){
      print $multifl $kee.",".$barcode_counts{$kee}."\n";
   }
}
close $multifl;
