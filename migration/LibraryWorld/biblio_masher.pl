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
my $branch_map_name = "";
my %branch_map;
my $itype_map_name = "";
my %itype_map;
my $loc_map_name = "";
my %loc_map;
my $type_loc_map_name = "";
my %type_loc_map;
my $type_call_map_name = "";
my %type_call_map;
my $type_loc_coll_map_name= "";
my %type_loc_coll_map;
my $collcode_map_name = "";
my %collcode_map;
my $lost_map_name = "";
my %lost_map;
my $damaged_map_name = "";
my %damaged_map;
my $notforloan_map_name = "";
my %notforloan_map;
my $default_branch = "";
my $drop_noitem = 0;


GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'branch_map=s'  => \$branch_map_name,
    'itype_map=s'   => \$itype_map_name,
    'type_loc_map=s' => \$type_loc_map_name,
    'type_call_map=s' => \$type_call_map_name,
    'type_loc_coll_map=s' => \$type_loc_coll_map_name,
    'loc_map=s'     => \$loc_map_name,
    'collcode_map=s' => \$collcode_map_name,
    'def_branch=s'  => \$default_branch,
    'lost_map=s'    => \$lost_map_name,
    'damaged_map=s' => \$damaged_map_name,
    'nfl_map=s'     => \$notforloan_map_name,
    'drop_noitem'   => \$drop_noitem,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $mapcsv = Text::CSV->new();

if ($lost_map_name ne q{}){
   open my $mapfile,"<$lost_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $lost_map{$data[0]}=$data[1];
   }
   close $mapfile;
}

if ($damaged_map_name ne q{}){
   open my $mapfile,"<$damaged_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $damaged_map{$data[0]}=$data[1];
   }
   close $mapfile;
}

if ($notforloan_map_name ne q{}){
   open my $mapfile,"<$notforloan_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $notforloan_map{$data[0]}=$data[1];
   }
   close $mapfile;
}

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

if ($type_loc_map_name ne q{}){
   open my $mapfile,"<$type_loc_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $type_loc_map{$data[0]}{$data[1]}=$data[2];
   }
   close $mapfile;
}

if ($type_call_map_name ne q{}){
   open my $mapfile,"<$type_call_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $type_call_map{$data[0]}{$data[1]}=$data[2];
   }
   close $mapfile;
}

if ($type_loc_coll_map_name ne q{}){
   open my $mapfile,"<$type_loc_coll_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $type_loc_coll_map{$data[0]}{$data[1]}{$data[2]}=$data[3];
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
my $no_852=0;
my $bad_852_nobarcode=0;
my $bad_852_noholdcode=0;
my %branch_counts;
my %itype_counts;
my %loc_counts;
my %collcode_counts;

RECORD:
while () {
   #last if ($debug and $i > 20);
   my $record = $batch->next();
   if ($@){
      print "Bogusness skipped\n";
      next RECORD;
   }
   last unless ($record);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;

   if (!$record->field("852")){
       $no_852++;
       next RECORD if ($drop_noitem);  
   }
   
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

   my $this_itype= substr($record->leader(),6 ,2);
   if (exists $itype_map{$this_itype}){
      $this_itype = $itype_map{$this_itype};
   }
ITMFIELD:
   foreach my $field ($record->field("852")){
      $j++;
      if (!$field->subfield('p')){
         $bad_852_nobarcode++;
         next ITMFIELD;;
      }
      my $barcode = $field->subfield('p');
      $itype{$barcode} = $this_itype;
      $loc{$barcode} = $field->subfield('k') || "";
      $itemcall{$barcode} = $field->subfield('h') || "";
      $collcode{$barcode} = $field->subfield('j') || "";

      if (exists $type_loc_map{$this_itype}{$loc{$barcode}}){
         $itype{$barcode} =  $type_loc_map{$this_itype}{$loc{$barcode}};
      }
      if (exists $type_call_map{$this_itype}{$field->subfield('h')}){
         $itype{$barcode} = $type_call_map{$this_itype}{$field->subfield('h')};
      }
      if (exists $type_loc_coll_map{$this_itype}{$field->subfield('k')}{$field->subfield('j')}){
         $debug and print "oi";
         $itype{$barcode} =  $type_loc_coll_map{$this_itype}{$field->subfield('k')}{$field->subfield('j')};
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

      $homebranch{$barcode} = $field->subfield('b');
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
      if ($field->subfield('9') ne q{}){
        $itmprice{$barcode} = $field->subfield('9');
        $replprice{$barcode} = $itmprice{$barcode};
      }

      $enumchron{$barcode} = $field->subfield('r') || "";

      $enumchron{$barcode} = undef if ($enumchron{$barcode} eq q{});

      if ($field->subfield('z')){
         $itemnote{$barcode} = $field->subfield('z');
      }
     
      if ($field->subfield('c') ne q{}){
         my $year = substr($field->subfield('c'),0,4);
         my $month = substr($field->subfield('c'),4,2);
         my $day = substr($field->subfield('c'),6,2);
         $acqdate{$barcode} = sprintf "%d-%02d-%02d",$year,$month,$day;
      }
      if ($field->subfield('6') ne q{}){
         my $year = substr($field->subfield('6'),0,4);
         my $month = substr($field->subfield('6'),4,2);
         my $day = substr($field->subfield('6'),6,2);
         $lastseen{$barcode} = sprintf "%d-%02d-%02d",$year,$month,$day;
      }
      if ($field->subfield('g') ne q{}){
         $issues{$barcode} = $field->subfield('g');
      }
      if ($field->subfield('u') ne q{}){
         $renews{$barcode} = $field->subfield('u');
      }
      if ($field->subfield('v') ne q{}){
         $holds{$barcode} = $field->subfield('v');
      }
      if ($field->subfield('m') ne q{}){
         my $year = substr($field->subfield('m'),0,4);
         my $month = substr($field->subfield('m'),4,2);
         my $day = substr($field->subfield('m'),6,2);
         $lastborrowed{$barcode} = sprintf "%d-%02d-%02d",$year,$month,$day;
      }
      if ($field->subfield('t') ne q{}){
         $copynum{$barcode} = $field->subfield('t');
      }
      my $status = $field->subfield('a');
      if (exists $notforloan_map{$status}){
         $notforloanstat{$barcode} = $notforloan_map{$status};
      }
      if (exists $damaged_map{$status}){
         $damstat{$barcode} = $damaged_map{$status};
      }
      if (exists $lost_map{$status}){
         $loststat{$barcode} = $lost_map{$status};
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
      $itmtag->update( "x" => $itemnote{$key} )  if ($itemnote{$key});
      $itmtag->update( "h" => $enumchron{$key} ) if ($enumchron{$key});
      $itmtag->update( "c" => $loc{$key} )       if ($loc{$key});
      $itmtag->update( "d" => $acqdate{$key} )   if ($acqdate{$key});
      $itmtag->update( "l" => $issues{$key} )    if ($issues{$key});
      $itmtag->update( "m" => $renews{$key} )    if ($renews{$key});
      $itmtag->update( "n" => $holds{$key} )     if ($holds{$key});
      $itmtag->update( "r" => $lastseen{$key} )  if ($lastseen{$key});
      $itmtag->update( "s" => $lastborrowed{$key} )  if ($lastborrowed{$key});
      $itmtag->update( "t" => $copynum{$key} )   if ($copynum{$key});
      $itmtag->update( "1" => $loststat{$key} )  if ($loststat{$key});
      $itmtag->update( "4" => $damstat{$key} )   if ($damstat{$key});
      $itmtag->update( "4" => $notforloanstat{$key} )   if ($notforloanstat{$key});
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

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_852 biblios with no 852.\n$bad_852_nobarcode 852s missing barcode.\n$bad_852_noholdcode 852s missing holding code.\n";
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

