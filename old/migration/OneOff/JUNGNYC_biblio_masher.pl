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
use Date::Calc;
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
my $written=0;
my $no_999=0;

while () {
   last if ($debug and $i > 9);
   my $record = $batch->next();
   last unless ($record);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }

   if (!$record->field("999")){
       $no_999++;
       print $outfl $record->as_usmarc();
       $written++;
       next;
   }
   my $itype = uc $record->subfield('997','a');
   my $call1 = $record->subfield('998','a');
   my $call2 = $record->subfield('998','b');
   my $call3 = $record->subfield('998','c');
   my $call4 = $record->subfield('998','d');
   my $tagcall1 = $call1;
   $tagcall1 =~ s/\://g;
   $tagcall1 =~ s/ //g;
   my $newcall = "$tagcall1 $call2 $call3 $call4";
   $newcall = uc $newcall;

   foreach my $field ($record->field("999")){
      $j++;
    
      my $item = $field->subfield('a');

      $item =~ s/$call1://g;
      $item =~ s/$call2://g;
      $item =~ s/$call3://g;
      $item =~ s/$call4://g;
      $item =~ s/$call1//g;
      $item =~ s/$call2//g;
      $item =~ s/$call3//g;
      $item =~ s/$call4//g;
      $item =~ s/c\..//g;
      $item =~ s/c\. .//g;
      $item =~ s/C\.//g;
      $item =~ s/\(\)//g;

      $item =~ s/\((.+)\)//;
      my $barcode = $1 || q{} ;
      if ($barcode eq q{}){
         $item =~ s/(S\d+)//;
         $barcode = $1;
      }
      if ($barcode eq q{}){
         $item =~ s/(\d\d+)//;
         $barcode = $1;
      }
      
     if ($barcode eq q{}){
        print "\nCan't find barcode:  Bib $i ($record->subfield('245','a')) Item $j\n";
     }
   
     $item =~ s/ : //g;
     $item =~ s/\s+/ /g;
     $item =~ s/\s+$//;

     my $enumchron = $item;

     $debug and print "BAR: $barcode ENUM: $enumchron ITYPE: $itype CALL: $newcall\n";

     if ($barcode ne q{}){
        my $itmtag = MARC::Field->new( 952, '', '', 
                                       'p' => $barcode,
                                       'o' => $newcall,
                                       'y' => $itype);
        $itmtag->update( 'h' => $enumchron ) if ($enumchron ne q{});
        $record->insert_grouped_field($itmtag);
     }

   }

   my $typtag = MARC::Field->new( 942, '', '', 'c' => $itype);
   $record->insert_grouped_field($typtag);

   foreach my $dumpfield($record->field('99.')){
      $record->delete_field($dumpfield);
   }

   print $outfl $record->as_usmarc();
   $written++;
}
 
close $infl;
close $outfl;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_999 biblios with no 999.\n";
