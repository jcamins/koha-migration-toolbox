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
my $drop_noitem = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'debug'         => \$debug,
    'drop_noitem'   => \$drop_noitem,
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
       next if ($drop_noitem);  
       print $outfl $record->as_usmarc();
       $written++;
       next;
   }
   
}
 
close $infl;
close $outfl;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_952 biblios with no 952.\n$bad_952 952s missing barcode or itemtype.\n";
