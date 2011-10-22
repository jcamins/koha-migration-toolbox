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
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $mapfile_name = "";
my $drop_noitem = 0;
my $dump_types_str="";
my %dump_types;


GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'drop_types=s'  => \$dump_types_str,
    'map=s'         => \$mapfile_name,
    'debug'         => \$debug,
    'drop_noitem'   => \$drop_noitem,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($mapfile_name eq '')){
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
my $mapcsv = Text::CSV->new();
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
print "\n$mapcount lines read.\n\nProcessing biblios.\n";

my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
open my $outfl,">:utf8",$outfile_name || die ('Cannot open outfile!');
warn Dumper($outfl);
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

while () {
   last if ($debug and $i > 99);
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);

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

   foreach my $field ($record->field("852")){
      $j++;
      if (!$field->subfield('p')){
         $bad_852_nobarcode++;
         next;
      }
      if (!$field->subfield('b')){
         $bad_852_noholdcode++;
         next;
      }
      if ($dump_types{uc($field->subfield('b'))}){
         $drop_type++;
         next;
      }
      my $barcode = $field->subfield('p');
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
      $replprice{$barcode} = $price if ($price);

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

      if ($field->subfield('z')){
         $itemnote{$barcode} = $field->subfield('z');
      }
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
        "2" => "lcc",
      );
      $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
      $itmtag->update( "h" => $enumchron{$key} ) if ($enumchron{$key});
      $itmtag->update( "c" => $loc{$key} ) if ($loc{$key} ne q{});
      

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

