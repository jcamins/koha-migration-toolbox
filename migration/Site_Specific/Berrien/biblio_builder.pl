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
use Text::CSV_XS;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
$|=1;
my $debug=0;

my $infile_name = "";
my $itemfile_name = "";
my $outfile_name = "";
my $default_branch = "";

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'item=s'       => \$itemfile_name,
    'def_branch=s' => \$default_branch,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($itemfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
my %itmhash;
if (1){
   my $itms = 0;
   print "Loading item data into memory.\n";
   open my $itmfl,"<$itemfile_name";
   while (my $itmline = readline($itmfl)){
      #$debug and last if ($itms > 24);
      $itms++;
      print ".";
      print "\r$itms" unless ($itms % 100);
      my (undef,$catkey,undef) = split (/,/,$itmline);
      push(@{$itmhash{$catkey}}, $itmline);
   }
   #$debug and warn Dumper(%itmhash);
   close $itmfl; 
   print "\n$itms items loaded.\n";
   print "Processing biblios.\n";
}
open my $infl,"<",$infile_name;
my $csv = Text::CSV_XS->new({binary => 1});
open my $outfl,">:utf8",$outfile_name;
my $i=0;
my $j=0;
my $written=0;
my %branchcount;
my %itypecount;
my %collcodecount;

while (my $line = $csv->getline($infl)) {
   #last if ($debug and $j > 2);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   my @row = @$line;
   my $biblio_key = $row[0];
   my $title = MARC::Field->new('245',' ',' ', 'a' => $row[1]);
   my $desc = MARC::Field->new('500',' ',' ', 'a' => $row[2]);
   my $record=MARC::Record->new();
   $record->leader('     nam a22        4500');
   $record->insert_fields_ordered($title);
   $record->insert_fields_ordered($desc);

   my @matches;
   foreach (@{$itmhash{$biblio_key}}){
     push(@matches,$_);
   }
   delete $itmhash{$biblio_key};

   if (scalar(@matches) ==0){ 
       $debug and print "no items\n";
       $debug and print $record->as_formatted();
       eval{ print $outfl $record->as_usmarc(); };
       $written++;
       next;
   }

   my %homebranch;
   my %holdbranch;
   my %itype;
   my %acqsource;
   my %collcode;
   my $keeper_itype;

   foreach (@matches){
      my $field= $_;
      #$debug and print $field."\n";
      $j++;
      my $line_csv = Text::CSV_XS->new();
      $line_csv->parse($field);
      my @itmrow = $line_csv->fields();
      
      my $barcode = $itmrow[2];
      $itype{$barcode} = $itmrow[0];
      $homebranch{$barcode} = $default_branch;
      $holdbranch{$barcode} = $default_branch;
      $acqsource{$barcode} = $biblio_key;
      $collcode{$barcode} = $itmrow[4];

      $itypecount{$itype{$barcode}}++;
      $keeper_itype=$itype{$barcode};
      $branchcount{$homebranch{$barcode}}++;
      $collcodecount{$collcode{$barcode}}++ if ($collcode{$barcode});

   }

   if ($keeper_itype){
      my $tag942=MARC::Field->new("942"," "," ", "c" => $keeper_itype);
      $record->insert_grouped_field($tag942);
   }

   foreach my $key (sort keys %homebranch){
      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $key,
        "a" => $homebranch{$key},
        "b" => $holdbranch{$key},
        "y" => $itype{$key},
      );
      $itmtag->update( "e" => $acqsource{$key} ) if ($acqsource{$key});
      $itmtag->update( "8" => $collcode{$key} ) if ($collcode{$key});

      $record->insert_grouped_field($itmtag);
   }
   my $outrec = $record->as_usmarc();
   if (length $outrec <= 99999){
      eval{ print $outfl $outrec; };
      $written++;
   }
   else {
      print "Long record skipped!\n";
   }
}
foreach my $kee (sort keys %itmhash){
   foreach (@{$itmhash{$kee}}){
      my $field= $_;
      #$debug and print $field."\n";
      $j++;
      my $line_csv = Text::CSV_XS->new();
      $line_csv->parse($field);
      my @itmrow = $line_csv->fields();

      my $biblio_key = $itmrow[1];
      my $title = MARC::Field->new('245',' ',' ', 'a' => $itmrow[3]);
      my $desc = MARC::Field->new('500',' ',' ', 'a' => $itmrow[6]);
      my $record=MARC::Record->new();
      $record->leader('     nam a22        4500');
      $record->insert_fields_ordered($title);
      $record->insert_fields_ordered($desc);

      my $barcode = $itmrow[2];
      my $itype = $itmrow[0];
      my $homebranch = $default_branch;
      my $holdbranch = $default_branch;
      my $acqsource = $biblio_key;
      my $collcode = $itmrow[4];

      $itypecount{$itype}++;
      my $keeper_itype=$itype;
      $branchcount{$homebranch}++;
      $collcodecount{$collcode}++ if ($collcode);
   if ($keeper_itype){
      my $tag942=MARC::Field->new("942"," "," ", "c" => $keeper_itype);
      $record->insert_grouped_field($tag942);
   }

      my $itmtag=MARC::Field->new("952"," "," ",
        "p" => $barcode,
        "a" => $homebranch,
        "b" => $holdbranch,
        "y" => $itype,
      );
      $itmtag->update( "e" => $acqsource ) if ($acqsource);
      $itmtag->update( "8" => $collcode ) if ($collcode);

      $record->insert_grouped_field($itmtag);
   my $outrec = $record->as_usmarc();
   if (length $outrec <= 99999){
      eval{ print $outfl $outrec; };
      $written++;
   }
   else {
      print "Long record skipped!\n";
   }
   }
}
close $outfl;
 
print "\n\n$i biblios read.\n$j items inserted.\n$written biblios written.\n";
print "\nBRANCHES:\n";
foreach my $kee (sort keys %branchcount){
   print $kee.":   ".$branchcount{$kee}."\n";
}
print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itypecount){
   print $kee.":   ".$itypecount{$kee}."\n";
}
print "\nCOLLECTION CODES\n";
foreach my $kee (sort keys %collcodecount){
   print $kee.":   ".$collcodecount{$kee}."\n";
}
print "\n";


