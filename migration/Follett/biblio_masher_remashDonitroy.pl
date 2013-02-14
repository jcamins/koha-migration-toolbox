#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -edited by Joy Nelson
# 
#---------------------------------
#attempt to make a pass two
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

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
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
my $h=0;
my $e=0;
my $w=0;
my $t=0;

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

   my %homebranch;
   my %holdbranch;
   my %itype;
   my %loc;
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

   foreach my $field ($record->field("952")){
      my $barcode;
      if ($field->subfield('p')){
         $barcode= $field->subfield('p');
      }
      $itype{$barcode} = $field->subfield('y');
      if ($field->subfield('t')) {
         $copynum{$barcode} = $field->subfield('t');
      }
      $itemcall{$barcode} = $field->subfield('o');
      if ($field->subfield('g')) {
         $itmprice{$barcode} = $field->subfield('g');
      }
      if ($field->subfield('v')) {
         $replprice{$barcode} = $field->subfield('v');
      }
      if ($field->subfield('c')) {
         $loc{$barcode} = $field->subfield('c');
      }
      if ($field->subfield('d')) {
         $acqdate{$barcode} = $field->subfield('d');
      }
      if ($field->subfield('e')) {
          $acqsource{$barcode} = $field->subfield('e');
      }      
      if ($field->subfield('r')) {
          $seendate{$barcode} = $field->subfield('r');
      }
      if ($field->subfield('x')) {
         $item_hidden_note{$barcode} = $field->subfield('x');
      }
      if ($field->subfield('8')) {
         $collcode{$barcode} = $field->subfield('8');
      }
      if ($field->subfield('z')) {
         $itemnote{$barcode} = $field->subfield('z');
      }
      if ($field->subfield('l')) {
         $issues{$barcode} = $field->subfield('l');
      }
      if ($field->subfield('h')) {
         $enumchron{$barcode} = $field->subfield('h');
      }
#add branchcode mapping here for callnumber
      my ($begincall, $midcall, $remainder) = split /\s+/, $itemcall{$barcode}, 3;
if (!$remainder) {$remainder = "";}
#print "REMAINDER: $remainder\n";
      if ($remainder eq "H") { 
       $homebranch{$barcode} = "DONIHIGH" ;
       $holdbranch{$barcode} = "DONIHIGH" ;
       $h++;
       }
       elsif ($remainder eq "W") {
       $homebranch{$barcode} = "DONIWATH";
       $holdbranch{$barcode} = "DONIWATH";
       $w++;
       }
       elsif ($remainder eq "E") {
       $homebranch{$barcode} = "DONIELWD";
       $holdbranch{$barcode} = "DONIELWD";
       $e++;
       }
       else {
       $homebranch{$barcode} = "DONITROY";
       $holdbranch{$barcode} = "DONITROY";
       $t++;
       }
#print "$homebranch{$barcode}\n";
   }
#end 952 loop

   foreach my $dumpfield($record->field('952')){
      $record->delete_field($dumpfield);
   }

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

         $record->insert_grouped_field($itmtag);
         $j++;
      }
      print $outfl $record->as_usmarc();
}
print "$j\n";
print "TROY $t\n";
print "HIGH $h\n";
print "ELWD $e\n";
print "WATH $w\n";

close $infl;
close $outfl;
