#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use autodie;
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
open my $outfl,">",$outfile_name;
my $i=0;
my $j=0;
my $written=0;

RECORD:
while () {
   last RECORD if ($debug and $i > 2);
   my $record = $batch->next();
   if ($@){
      print "Bogusness skipped\n";
      next RECORD;
   }
   last RECORD unless ($record);
   $i++;
   print "." unless $i % 10;
   print "\r$i" unless $i % 100;

   next RECORD if !$record->field("999");

FIELD:
   foreach my $field ($record->field("999")){
      $j++;
      next FIELD if !$field->subfield('e');

      my $barcode = $field->subfield('i');
      my $seendate = q{};

      if ($field->subfield('e')){
         my ($month,$day,$year) = split(/\//,$field->subfield('e'));
         if ($month && $day && $year){
            $seendate = sprintf "%4d-%02d-%02d",$year,$month,$day;
         }
      }
      if ($seendate ne q{}){
        print $outfl "$barcode,$seendate\n";
        $written++;
      }
   }
}
 

print "\n\n$i biblios read.\n$j items read.\n$written records written.\n";
