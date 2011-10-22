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
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;


my $infile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
);

if ($infile_name eq ''){
    print << 'ENDUSAGE';

Usage:  analyzer --in=<infile> 

<infile>     A MARC-formatted data file, from which you wish to extract data.

ENDUSAGE
exit;
}

my $fh = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$fh);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
my $i=0;
my %locations;
my $no_949=0;
my $no_holdcode=0;
while () {
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);
   
   if (!$record->field("949")){
       $no_949++;
       next;
   }

   foreach my $field ($record->field("949")){
      
      if ($field->subfield("a")){
          my $this=uc substr($field->subfield("a"),1,99);
          $locations{$this}++; 
      }
      else {
          $no_holdcode++; 
      }
   }

}

print "\n\nRESULTS BY LOCATION CODE\n";
foreach my $kee (sort keys %locations){
   print $kee.":   ".$locations{$kee}."\n";
}

print "\nCOUNTS OF NO-ITEMS TYPES:\n";
print "NO HOLD CODE: $no_holdcode\nNO 949s: $no_949\n\n";
