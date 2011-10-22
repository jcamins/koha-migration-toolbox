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
my $no_952=0;
my $bad_952=0;

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
       print $outfl $record->as_usmarc();
       $written++;
       next;
   }
  
   my $keeptype; 

   foreach my $field ($record->field("952")){
      $j++;

      $field->add_subfields( 'o' => $field->subfield('O'));
      $field->delete_subfield( code => 'O');
 
      my $itype = $field->subfield('y');
      if ($itype eq " "){
         $field->update( 'y' => 'UNKNOWN');
      }
      if ($itype eq "TECHNICAL ARTICLE"){
         $field->update( 'y' => 'TECH');
      }

      my $location = $field->subfield('c');
      if ($location eq " "){
         $field->update( 'c' => 'UNKNOWN');
      }
      if ($location eq "ARCHIVE STORAGE"){
         $field->update( 'c' => 'ARCSTOR');
      }
      if ($location eq "TECHNICAL ARCHIVE STORAGE"){
         $field->update( 'c' => 'TECHSTOR');
      }

      my $collcode = $field->subfield('8');
      if ($collcode =~ /CD/){
         $field->update( 'y' => 'CD');
      }
      if ($collcode =~ /DVD/){
         $field->update( 'y' => 'DVD');
      }
      $field->delete_subfield( code => '8');

      my $keeptype = $field->subfield('y');
   }

   my $typtag = MARC::Field->new( 942, '', '', 'c' => $keeptype);
   $record->insert_grouped_field($typtag);

   print $outfl $record->as_usmarc();
   $written++;
}
 
close $infl;
close $outfl;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_952 biblios with no 952.\n$bad_952 952s missing barcode or itemtype.\n";
