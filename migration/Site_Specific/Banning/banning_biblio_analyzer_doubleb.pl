#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -edited by Joy Nelson
#  -7/30/2012
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
my $outfile_name = "";
my $create = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'debug'         => \$debug,
    'create'        => \$create,
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
my $no_852=0;
my $bad_852=0;
my %types;
my %collcodes;
my $itype;
my $ccode;
my $newsubfield;
my %j_sub;
my $jvalue;
my $itembarcode;

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
       next;
   }
   
   foreach my $field ($record->field("852")){
      $j++;
      if (!$field->subfield('p')){
         $bad_852++;
      }
      else {
         $itembarcode = $field->subfield('p');
      }

     #852$x@ parsing here.....

SUBX:
   foreach my $xsubfield ($field->subfield('x')) {
    if ($xsubfield =~ /COPYID:[0-9]+/) { 
      next SUBX;
      }
    
      my @newsubfield = split /\@/, $xsubfield;
      my $bcount;

$bcount = 0;
$ccode = '';
      foreach $newsubfield(@newsubfield) {
       my $subsubfield = substr $newsubfield, 0,1;

        if ($subsubfield eq 'a' ) {
         $itype = substr $newsubfield, 1;
         $types{uc($itype)}++;
         }
         else {
         $types{'NONE'}++;
         }

         if ($subsubfield eq 'j' ) {
          $jvalue = substr $newsubfield, 1;
          $j_sub{uc($jvalue)}++;
         }
         else {
          $j_sub{'NONE'}++;
         }
        
         if ($subsubfield eq 'b' ) {
          $ccode .= " @ " . substr $newsubfield, 1;
          $collcodes{uc($ccode)}++;
          $bcount++;
          }
         else {
          $collcodes{'NONE'}++;
          }
      }
          if ($bcount > 1) {
            print "\n$itembarcode :  $ccode\n";
          }

   }   
  }  
}


close $outfl;

