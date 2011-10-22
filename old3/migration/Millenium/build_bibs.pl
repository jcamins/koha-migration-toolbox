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
use Text::CSV;
use C4::Context;
use MARC::Batch;
use MARC::Charset;
use MARC::Field;
use MARC::Record;

$|=1;
my $debug=0;

my $infile_name = "";
my $branch = "";
my $circs = "";
my $shelfloc_map_name = "";
my %shelfloc_map;
my $itype_map_name = "";
my %itype_map;
my $deftype="";
my $collcode_map_name = "";
my %collcode_map;


GetOptions(
    'in=s'              => \$infile_name,
    'branch=s'          => \$branch,
    'circs=s'           => \$circs,
    'shelfloc_map=s'    => \$shelfloc_map_name,
    'itype_map=s'       => \$itype_map_name,
    'deftype=s'         => \$deftype,
    'debug'             => \$debug,
);

if (($branch eq '') || ($infile_name eq '')){
  print "Something's missing.\n";
  exit;
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

my $dbh = C4::Context->dbh();

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
open my $out,">:utf8","biblios_".$branch.".mrc";
my $sth = $dbh->prepare("SELECT * FROM temp_iii_items WHERE biblio=?");
my $i=0;
my $j=0;
my %permloc;
my %curloc;
my %shelfloc;
my %itypes;
my %itype_942;

while (){
   $debug and last if ($i == 20);
   my $record = $batch->next();
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
 
   my $itemcall = ""; 
   if ($record->field("050")){
      $itemcall = $record->subfield("050","a");
      if ($record->subfield("050","b")){
         $itemcall .= " ".$record->subfield("050","b");
      }
   }

   my $biblio = $record->subfield("907","a");
   if ($biblio){
   $biblio =~ s/^\.//;
   $debug and print "\n$biblio\n";
   $sth->execute($biblio);
   my %homebranch;
   my %holdbranch;
   my %itype;
   my %loc;
   my %collcode;
   my %acqdate;
   my %acqsource;
   my %seendate;
   my %item_hidden_note;
   my %copynum;
   my %itemcall;
   my %itemnote;
   my %issues;
   my %renews;
   my %enumchron;
   my $keeper_itype;

   while(my $row = $sth->fetchrow_hashref()){
      $debug and warn Dumper($row);
      $j++;
      my $barcode=$row->{'barcode'};
      $homebranch{$barcode} = $branch;
      $holdbranch{$barcode} = $branch;
      $itype{$barcode} = $row->{'itype'};
      $loc{$barcode} = uc($row->{'location'});
      $loc{$barcode} =~ s/ //g;
      if ($loc{$barcode} && exists $shelfloc_map{$loc{$barcode}}){
         $loc{$barcode} = $shelfloc_map{$loc{$barcode}};
      }
      $shelfloc{$loc{$barcode}}++ if ($loc{$barcode});
      if (exists $itype_map{$itype{$barcode}}){
         $itype{$barcode}=$itype_map{$itype{$barcode}};
      }
      $itypes{$itype{$barcode}}++;
      $keeper_itype=$itype{$barcode};
      $copynum{$barcode} = $row->{'copynum'};
      if ($row->{'code2'} ){
         if ($row->{'code2'} eq "g"){
            $acqsource{$barcode}="Gift";
         }
      }
      if ($circs && $row->{'duedate'}){
         print $circfl $row->{'borrbar'}.",".$barcode.","._process_date($row->{'ckodate'}).",".
                       _process_date($row->{'duedate'})."\n";
      }
      if ($row->{'duedate'}){
         $seendate{$barcode} = _process_date($row->{'duedate'});
      }
      $renews{$barcode} = $row->{'renews'};
      $issues{$barcode} = $row->{'checkouts'};
      $acqdate{$barcode} = _process_date($row->{'accessiondate'});
      $enumchron{$barcode} = $row->{'enumchron'};
      if (!$seendate{$barcode} && $row->{'editdate'}){
         $seendate{$barcode}=_process_date($row->{'editdate'});
      }
      if($row->{'opacmsg'}){
         $row->{'opacmsg'} = undef if ($row->{'opacmsg'} eq " ");
      }
      $itemnote{$barcode} = $row->{'opacmsg'};
      if ($row->{'note1'} || $row->{'note2'}){
         $item_hidden_note{$barcode} = "";
         $item_hidden_note{$barcode} .= $row->{'note1'} if ($row->{'note1'});
         $item_hidden_note{$barcode} .= " -- " if ($row->{'note2'} && $item_hidden_note{$barcode});
         $item_hidden_note{$barcode} .= $row->{'note2'} if ($row->{'note2'});
      }
   }
   foreach my $dumpfield($record->field('942')){
      $record->delete_field($dumpfield);
   }
   foreach my $dumpfield($record->field('952')){
      $record->delete_field($dumpfield);
   }
   if (!$keeper_itype){
      $keeper_itype=$deftype;
   }
   if ($keeper_itype){
      my $tag942 = MARC::Field->new("942"," "," ", "c" => $keeper_itype);
      $record->insert_grouped_field($tag942);
      $itype_942{$keeper_itype}++;
   }

   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $holdbranch{$key},
        "o" => $itemcall,
        "y" => $itype{$key},
        "2" => "lcc",
      );
      $itmtag->update( "d" => $acqdate{$key} ) if ($acqdate{$key});
      $itmtag->update( "e" => $acqsource{$key} ) if ($acqsource{$key});
      $itmtag->update( "c" => $loc{$key} ) if ($loc{$key});
      $itmtag->update( "r" => $seendate{$key} ) if ($seendate{$key});
      $itmtag->update( "x" => $item_hidden_note{$key} ) if ($item_hidden_note{$key});
      $itmtag->update( "8" => $collcode{$key} ) if ($collcode{$key});
      $itmtag->update( "t" => $copynum{$key} ) if ($copynum{$key});
      $itmtag->update( "z" => $itemnote{$key} ) if ($itemnote{$key});
      $itmtag->update( "l" => $issues{$key} ) if ($issues{$key});
      $itmtag->update( "m" => $renews{$key} ) if ($renews{$key});
      $itmtag->update( "h" => $enumchron{$key} ) if ($enumchron{$key});

      $record->insert_grouped_field($itmtag);
   }
   }
   print $out $record->as_usmarc();
}
close $out;
print "\n$i biblios read.\n$j items attached.";

print "\nSHELVING LOCATIONS:\n";
foreach my $kee (sort keys %shelfloc){
   print $kee.":   ".$shelfloc{$kee}."\n";
}
print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itypes){
   print $kee.":   ".$itypes{$kee}."\n";
}
print "\nITEM TYPES (942):\n";
foreach my $kee (sort keys %itype_942){
   print $kee.":   ".$itype_942{$kee}."\n";
}
print "\n";

exit;

sub _process_date {
   my $datein = shift;
   my ($date,undef) = split(/ /,$datein);
   my ($month,$day,$year)= split(/-/,$date);
   $year += 1900 if $year <100;
   my $fixeddate = sprintf "%4d-%02d-%02d",$year,$month,$day;
   return $fixeddate;
}


