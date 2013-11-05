#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use MARC::Batch;
use MARC::Record;
use MARC::Field;
use MARC::Charset;
use Business::ISBN;
use Business::ISSN;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename  = $NULL_STRING;
my $output_filename = $NULL_STRING;
my $tag_field       = $NULL_STRING;
my $tag_subfield    = $NULL_STRING;
my $bar_subfield    = $NULL_STRING;

GetOptions(
    'in=s'          => \$input_filename,
    'out=s'         => \$output_filename,
    'tag=s'         => \$tag_field,
    'sub=s'         => \$tag_subfield,
    'bar=s'         => \$bar_subfield,
    'debug'         => \$debug,
);

for my $var ($input_filename,$output_filename,$tag_field,$tag_subfield,$bar_subfield) {
   croak ('You are missing something') if $var eq $NULL_STRING;
}

my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();

open my $out,'>',$output_filename;

RECORD:
while (){
   my $marc;
   eval {$marc = $batch->next();};
   if ($@) {
      print "Bogus record skipped.\n";
      next RECORD;
   }
   last RECORD unless ($marc);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   if ($@){
      print "bogus record skipped\n";
      next RECORD;
   }
FIELD:
   foreach my $field ($marc->field($tag_field)) {
      my $data = $field->subfield($tag_subfield) || $NULL_STRING;
      my $barcode = $field->subfield($bar_subfield) || $NULL_STRING;
      $debug and print "Data: $data\n";
      next FIELD if ($data eq $NULL_STRING) || ($barcode eq $NULL_STRING);
      print {$out} "$barcode,$data\n";
      $written++;
   }
}

close $out;

print "\n$i records read from database.\n$written lines in output file.\n";

exit;

