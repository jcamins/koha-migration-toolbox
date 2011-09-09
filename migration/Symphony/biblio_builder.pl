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
my $itemfile_name = "";
my $outfile_name = "";
my $codesfile_name = "";
my $quint_map_name = "";
my %quint_map;
my $branch_map_name = "";
my %branch_map;
my $shelfloc_map_name = "";
my %shelfloc_map;
my $itype_map_name = "";
my %itype_map;
my $collcode_map_name = "";
my %collcode_map;
my $type_location_map_name = "";
my %type_location_map;
my $type_ccode_map_name = "";
my %type_ccode_map;
my $callscheme_map_name = "";
my %callscheme_map;
my $drop_noitem = 0;
my $drop_collcodes=0;
my $dump_types_str = "";
my %dump_types;
my $dont_force_codes = 0;
my $reverse_cats = 0;
my $create=0;
my $use_hash=0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'item=s'       => \$itemfile_name,
    'codes=s'      => \$codesfile_name,
    'quintmap=s'        => \$quint_map_name,
    'branch_map=s'      => \$branch_map_name,
    'shelfloc_map=s'    => \$shelfloc_map_name,
    'itype_map=s'       => \$itype_map_name,
    'type_location_map=s' => \$type_location_map_name,
    'type_ccode_map=s'    => \$type_ccode_map_name,
    'collcode_map=s'    => \$collcode_map_name,
    'callscheme_map=s'  => \$callscheme_map_name,
    'drop_noitem'   => \$drop_noitem,
    'drop_types=s'    => \$dump_types_str,
    'reverse_cats'  => \$reverse_cats,
    'dontforce'     => \$dont_force_codes,
    'create'        => \$create,
    'use_hash'      => \$use_hash,
    'drop_collcodes' => \$drop_collcodes,
    'debug'         => \$debug,
);

if ($dump_types_str){
   foreach my $typ (split(/,/,$dump_types_str)){
      $dump_types{$typ}=1;
   }
}

if (($infile_name eq '') || ($outfile_name eq '') || ($itemfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
if (($create) && ($codesfile_name eq "")){
  print "Something's missing.\n";
  exit;
}

if ($quint_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$quint_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $quint_map{$data[0]}{$data[1]}{$data[2]}{$data[3]}{$data[4]} = [ $data[6],$data[7],$data[8],$data[9] ];
   }
   close $mapfile;
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
#$debug and print Dumper(%branch_map);

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

if ($type_location_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$type_location_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $type_location_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($type_ccode_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$type_ccode_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $type_ccode_map{$data[0]} = $data[1];
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

if ($callscheme_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$callscheme_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $callscheme_map{$data[0]} = $data[1];
   }
   close $mapfile;
}
my %itmhash;
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
      $itmline =~ s///g;
      my ($catkey,$rest) = split(/\|/,$itmline,2);
      push(@{$itmhash{$catkey}}, $itmline);
   }
   #$debug and warn Dumper(%itmhash);
   close $itmfl; 
   print "\n$itms items loaded.\n";
   print "Processing biblios.\n";
}
my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');
open my $outfl,">:utf8",$outfile_name;
my $i=0;
my $j=0;
my $written=0;
my $drop_type=0;
my $dropped_noitems=0;
my %branchcount;
my %itypecount;
my %loccount;
my %collcodecount;
my %collcode_desc;
my %callschemecount;
my %itype_942count;
my $no_999=0;

while () {
   #last if ($debug and $j > 2);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   my $record;
   eval {$record = $batch->next();};
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);
   my $biblio_key = $record->subfield("998","a");
   $biblio_key =~ s/^a//;
   #$debug and print "BIBLIO: $biblio_key\n";
   foreach my $dumpfield($record->field('9..')){
      $record->delete_field($dumpfield) if (($dumpfield->tag() ne '945') && ($dumpfield->tag() ne '998'));
   }
   foreach my $dumpfield($record->field('852')){
      $record->delete_field($dumpfield);
   }

   
   my $price = 0;

   if ($record->subfield("350","a")){
      $price = $record->subfield("350","a");
      #$price =~ s/\D\.]//;
      $price =~ s/(\d+(\.[0-9]{2}))/$1/;
      $price =~ s/\$//g;
   }

   my @matches;
   if ($use_hash){
      foreach (@{$itmhash{$biblio_key}}){
         push(@matches,$_);
      }
   }
   else{
      @matches = qx{grep "^$biblio_key\|" $itemfile_name};
   }

   if (scalar(@matches) ==0){ 
       $debug and print "no items\n";
       $no_999++;
       next if ($drop_noitem);  
       eval{ print $outfl $record->as_usmarc(); };
       $written++;
       next;
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
   my %withdrawn;
   my %itmlost;
   my %callscheme;
   my $keeper_itype;
   my $thiscount=0;

   foreach (@matches){
      my $field= $_;
      #$debug and print $field."\n";
      $j++;
      $thiscount++;
      my ($catkey,$barcode,$rest)= split(/\|/,$field,3);
      $barcode =~ s/ //g;
      my ($tmpseen,$tmpaccession,$tmpprice,$cat1,$cat2);
      ($itype{$barcode},$loc{$barcode},$cat1,$cat2,$homebranch{$barcode},
       $tmpseen,$issues{$barcode},$tmpaccession,$tmpprice,$callscheme{$barcode},
       $itemcall{$barcode},undef) = split(/\|/,$rest);

      if ($dump_types{$itype{$barcode}}){
         $drop_type++;
         delete $homebranch{$barcode};
         next;
      }
      
      if ($loc{$barcode} eq "DISCARDS"){
         $withdrawn{$barcode} = 1;
      }

      if ($loc{$barcode} eq "LOST" || $loc{$barcode} eq "LOST_ASSUM"){
         $itmlost{$barcode} = 1;
      }

      if ($loc{$barcode} eq "MISSING"){
         $itmlost{$barcode} = 4;
      }

      if (exists  $quint_map{$homebranch{$barcode}}{$itype{$barcode}}{$loc{$barcode}}{$cat1}{$cat2}){
         my @newdata_arr = @{ $quint_map{$homebranch{$barcode}}{$itype{$barcode}}{$loc{$barcode}}{$cat1}{$cat2} };
         #$debug and print Dumper(@newdata_arr);
         $homebranch{$barcode} = $newdata_arr[0];
         $itype{$barcode} = $newdata_arr[1];
         $loc{$barcode} = $newdata_arr[2];
         $collcode{$barcode} = $newdata_arr[3];
      }
      else{
         $debug and print "Old style:$biblio_key\n";
         if (exists($type_location_map{$itype{$barcode}})){
            if (!$dont_force_codes || ($dont_force_codes && $loc{$barcode} eq q{})){
               $loc{$barcode} = $type_location_map{$itype{$barcode}};
            }
         }

         if (exists($type_ccode_map{$itype{$barcode}})){
            $collcode{$barcode} = $type_ccode_map{$itype{$barcode}};
         }

         if (exists($itype_map{$itype{$barcode}})){
            $itype{$barcode} = $itype_map{$itype{$barcode}};
         }

         if (exists($shelfloc_map{$loc{$barcode}})){
            $loc{$barcode} = $shelfloc_map{$loc{$barcode}};
         }
      
         if (exists($branch_map{$homebranch{$barcode}})){
            $homebranch{$barcode} = $branch_map{$homebranch{$barcode}};
         }

         if ($reverse_cats){
            ($cat1,$cat2) = ($cat2,$cat1);
         }
         my $part1 = $cat1 ? substr($cat1,0,2) : "__";
         my $part2 = $cat2 ? substr($cat2,0,8) : "________";
         my $finalcode = $part1.$part2;

         my $desc1 = $cat1 ? $cat1 : "NULL";
         my $desc2 = $cat2 ? $cat2 : "NULL";
         my $finaldesc = $desc1."/".$desc2;

         $collcode{$barcode} = "";
         $collcode{$barcode} = $finalcode if ($finalcode ne "__________");
         if (exists($collcode_map{$collcode{$barcode}})){
            $collcode{$barcode} = $collcode_map{$collcode{$barcode}};
         }
      }

      if ($drop_collcodes || $collcode{$barcode} eq q{}){
         $collcode{$barcode} = undef;
      }
      
      if ($loc{$barcode} eq q{}){
         $loc{$barcode} = undef;
      } 

      $itypecount{$itype{$barcode}}++;
      $keeper_itype=$itype{$barcode};
      $branchcount{$homebranch{$barcode}}++;
      $holdbranch{$barcode} = $homebranch{$barcode};
      $loccount{$loc{$barcode}}++ if $loc{$barcode};
      $collcode_desc{$collcode{$barcode}} = $collcode{$barcode} if $collcode{$barcode};
      $collcodecount{$collcode{$barcode}}++ if ($collcode{$barcode});

      #$copynum{$barcode} = $thiscount;

      if ($tmpaccession){
         my $year=substr($tmpaccession,0,4);
         my $month=substr($tmpaccession,4,2);
         my $day=substr($tmpaccession,6,2);      
         if ($month && $day && $year){
            $acqdate{$barcode} = sprintf "%4d-%02d-%02d",$year,$month,$day;
         }
      }

      if ($tmpseen){
         my $year=substr($tmpseen,0,4);
         my $month=substr($tmpseen,4,2);
         my $day=substr($tmpseen,6,2);      
         if ($month && $day && $year){
            $seendate{$barcode} = sprintf "%4d-%02d-%02d",$year,$month,$day;
         }
      }
 
      if ($tmpprice){
         $itmprice{$barcode} = $tmpprice/100;
         $replprice{$barcode} = $tmpprice/100;
      }
      else {
         $itmprice{$barcode} = $price if ($price);
         $replprice{$barcode} = $price if ($price);
      }

      if (exists($callscheme_map{$callscheme{$barcode}})){
         $callscheme{$barcode} = $callscheme_map{$callscheme{$barcode}};
      }
      $callschemecount{$callscheme{$barcode}}++ if ($callscheme{$barcode});
   }

   if ($keeper_itype){
      my $tag942=MARC::Field->new("942"," "," ", "c" => $keeper_itype);
      $record->insert_grouped_field($tag942);
      $itype_942count{$keeper_itype}++;
   }
   my $there_are_items=0;

   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $holdbranch{$key},
        "o" => $itemcall{$key},
        "y" => $itype{$key},
        "g" => $itmprice{$key},
        "v" => $replprice{$key},
        "2" => $callscheme{$key},
      );
      $itmtag->update( "c" => $loc{$key} ) if ($loc{$key});
      $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
      $itmtag->update( "r" => $seendate{$key} ) if ($seendate{$key});
      $itmtag->update( "x" => $item_hidden_note{$key} ) if ($item_hidden_note{$key});
      $itmtag->update( "8" => $collcode{$key} ) if ($collcode{$key});
      $itmtag->update( "t" => $copynum{$key} ) if ($copynum{$key});
      $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
      $itmtag->update( "l" => $issues{$key} ) if ($issues{$key});
      $itmtag->update( "0" => $withdrawn{$key} ) if ($withdrawn{$key});
      $itmtag->update( "1" => $itmlost{$key} ) if ($itmlost{$key});

      $record->insert_grouped_field($itmtag);
      $there_are_items=1;
   }
   unless ($drop_noitem && !$there_are_items){
      my $outrec = $record->as_usmarc();
      if (length $outrec <= 99999){
         eval{ print $outfl $outrec; };
         $written++;
      }
      else {
         print "Long record skipped!\n";
      }
   }
   else {
      $dropped_noitems++;
   }
}
 

print "\n\n$i biblios read.\n$j items inserted.\n$written biblios written.\n$dropped_noitems biblios dropped for want of items.\n$no_999 biblios with no 999.\n$drop_type items dropped by type.\n";
print "\nBRANCHES:\n";
foreach my $kee (sort keys %branchcount){
   print $kee.":   ".$branchcount{$kee}."\n";
}
print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itypecount){
   print $kee.":   ".$itypecount{$kee}."\n";
}
print "\nITEM TYPES (942):\n";
foreach my $kee (sort keys %itype_942count){
   print $kee.":   ".$itype_942count{$kee}."\n";
}
print "\nSHELVING LOCATIONS:\n";
foreach my $kee (sort keys %loccount){
   print $kee.":   ".$loccount{$kee}."\n";
}
print "\nCOLLECTION CODES\n";
foreach my $kee (sort keys %collcodecount){
   print $kee.":   ".$collcodecount{$kee}."\n";
}
print "\nCALL SCHEMA\n";
foreach my $kee (sort keys %callschemecount){
   print $kee.":   ".$callschemecount{$kee}."\n";
}
print "\n";
close $outfl;

exit if (!$create);

open $outfl,">$codesfile_name";
print $outfl "# Branches\n";
foreach my $kee (sort keys %branchcount){
   print $outfl "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print $outfl "# Locations\n";
foreach my $kee (sort keys %loccount){
   if ($kee ne "NONE"){
      print $outfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','$kee');\n";
   }
}
print $outfl "# Item Types\n";
foreach my $kee (sort keys %itypecount){
   print $outfl "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','$kee');\n";
}
print $outfl "# Collection Codes\n";
foreach my $kee (sort keys %collcodecount){
   if ($collcode_desc{$kee} ne "NULL/NULL"){
      print $outfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','$collcode_desc{$kee}');\n";
   }
}
close $outfl;


