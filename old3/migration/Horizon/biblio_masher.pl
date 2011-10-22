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
use Getopt::Long;
use Data::Dumper;
use Text::CSV;
use Date::Calc;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $branch_override = "";
my $circs = "";
my $drop_noitem = 0;
my $dump_types_str="";
my %dump_types;
my $status_map_name="";
my %status_map;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'branch=s'      => \$branch_override,
    'circs=s'       => \$circs,
    'debug'         => \$debug,
    'drop_noitem'   => \$drop_noitem,
    'drop_types=s'  => \$dump_types_str,
    'status_map=s'  => \$status_map_name,
);

if ($dump_types_str){
   foreach my $typ (split(/,/,$dump_types_str)){
      $dump_types{$typ}=1;
   }
}

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

if ($status_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$status_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $status_map{$data[0]}[0] = $data[1];
      $status_map{$data[0]}[1] = $data[2];
   }
   close $mapfile;
}
$debug and print Dumper(%status_map);

my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
my $circfl;
if ($circs){
   open $circfl,">",$circs;
   print $circfl "Cardnumber, Barcode, Date_Out, Date_Due\n";
}
open my $outfl,">:utf8",$outfile_name;
my $i=0;
my $j=0;
my $written=0;
my $no_952=0;
my $bad_952=0;
my $drop_type=0;

while () {
   last if ($debug and $i > 99);
   my $record = $batch->next();
   last unless ($record);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }

   if (!$record->field("952")){
       $no_952++;
       next if ($drop_noitem);  
       foreach my $dumpfield($record->field('9..')){
          $record->delete_field($dumpfield);
       }
       print $outfl $record->as_usmarc();
       $written++;
       next;
   }
   
   my %homebranch;
   my %holdbranch;
   my %itype;
   my $keep_itype;
   my %collcode;
   my %acqdate;
   my %seendate;
   my %item_hidden_note;
   my %copynum;
   my %itemcall;
   my %itemnote;
   my %issues;
   my %enumchron;
   my %lostval;
   my %noloanval;
   my %damageval;
   my $items_on_this=0;

   foreach my $field ($record->field("952")){
      $j++;
      $items_on_this++;
#      if (!$field->subfield('i') || !$field->subfield('b')){
#         print "\nBad 952 record found!\n---------\n";
#         print Dumper($field);
#         print "\n\n";
#         $bad_952++;
#         next;
#      }

      if ($dump_types{uc($field->subfield('i'))}){
         $drop_type++;
         next;
      }
      
      my $barcode = $field->subfield('b');

      $itype{$barcode} = uc($field->subfield('i'));
      $keep_itype = $itype{$barcode};
      $copynum{$barcode} = $items_on_this; 
      if ($branch_override){
         $homebranch{$barcode} = $branch_override;
         $holdbranch{$barcode} = $branch_override;
      }
      else {   # TODO: these values may be wrong!
         $homebranch{$barcode} = $field->subfield('m');
         $holdbranch{$barcode} = $field->subfield('m');
      }
      $itemcall{$barcode} = $field->subfield('d');
      $issues{$barcode} = $field->subfield('l');
      
      if ($field->subfield('e')){
         $enumchron{$barcode} = $field->subfield('e');
      }
     
      if ($field->subfield('h')){
         $itemnote{$barcode} = $field->subfield('h');
      }
     
      if ($field->subfield('f')){
         my ($year,$month,$day) = Date::Calc::Add_Delta_Days(1970,1,1,$field->subfield('f'));
         $acqdate{$barcode} = sprintf "%4d-%02d-%02d",$year,$month,$day;
      }

      if ($field->subfield('k')){
         my ($year,$month,$day) = Date::Calc::Add_Delta_Days(1970,1,1,$field->subfield('k'));
         $seendate{$barcode} = sprintf "%4d-%02d-%02d",$year,$month,$day;
      }
  
      if ($field->subfield('c')){
         $collcode{$barcode} = uc($field->subfield('c'));
      }
      if ($circs && $field->subfield('n')){
         print $circfl $field->subfield('m').",".$barcode.",".$seendate{$barcode}.",";
         my ($year,$month,$day) = Date::Calc::Add_Delta_Days(1970,1,1,$field->subfield('n'));
         printf $circfl "%4d-%02d-%02d\n",$year,$month,$day;
      }
      if ($field->subfield('j')){
         if ($status_map{$field->subfield('j')}[0]){
            if ($status_map{$field->subfield('j')}[0] eq "LOST"){
               $lostval{$barcode} = $status_map{$field->subfield('j')}[1];
            }
            if ($status_map{$field->subfield('j')}[0] eq "NOLOAN"){
               $noloanval{$barcode} = $status_map{$field->subfield('j')}[1];
            }
            if ($status_map{$field->subfield('j')}[0] eq "DAMAGE"){
               $damageval{$barcode} = $status_map{$field->subfield('j')}[1];
            }
         }
      }
   }

   foreach my $dumpfield($record->field('9..')){
      $record->delete_field($dumpfield);
   }

   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $holdbranch{$key},
        "o" => $itemcall{$key},
        "y" => $itype{$key},
        "2" => "nlm",
      );
      $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
      $itmtag->update( "r" => $seendate{$key} ) if ($seendate{$key});
      $itmtag->update( "x" => $item_hidden_note{$key} ) if ($item_hidden_note{$key});
      $itmtag->update( "8" => $collcode{$key} ) if ($collcode{$key});
      $itmtag->update( "t" => $copynum{$key} ) if ($copynum{$key});
      $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
      $itmtag->update( "l" => $issues{$key} ) if ($issues{$key});
      $itmtag->update( "h" => $enumchron{$key} ) if ($enumchron{$key});
      $itmtag->update( "1" => $lostval{$key} ) if ($lostval{$key});
      $itmtag->update( "7" => $noloanval{$key} ) if ($noloanval{$key});
      $itmtag->update( "4" => $damageval{$key} ) if ($damageval{$key});

      $record->insert_grouped_field($itmtag);  
   }
   if ($keep_itype){
      my $typtag=MARC::Field->new("942"," "," ",
                   "c" => $keep_itype,
      );
      $record->insert_grouped_field($typtag);
   }

   print $outfl $record->as_usmarc();
   $written++;
}
 
close $infl;
close $outfl;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_952 biblios with no 952.\n$bad_952 952s missing barcode or itemtype.\n$drop_type items dropped due to itemtype.\n";
