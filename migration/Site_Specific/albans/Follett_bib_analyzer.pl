#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -edited by Joy Nelson
#  -12/26/2012
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
my %h_sub;
my @callnumber;

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

      if ($field->subfield('h')) {
        my $h_sub = $field->subfield('h');
        $h_sub =~ s/^\s+//;
        @callnumber = split (/ /,$h_sub);
        if ($callnumber[0] =~ /^[0-9]+/ ){
           $callnumber[0] = '####';
        }
        if ($callnumber[1] =~ /^[0-9]+/ ) {
           $callnumber[1] = '####';
        }
        if (($callnumber[0] eq 'LP') || ($callnumber[0] eq 'JUV') || ($callnumber[0] eq 'DVD') || ($callnumber[0] eq 'CD') || ($callnumber[0] eq 'MP3') || ($callnumber[0] eq 'VT') || ($callnumber[0] eq 'YA') ) {
        $h_sub{($callnumber[0]." ".$callnumber[1])}++;
        }
        else {
        $h_sub{($callnumber[0])}++;
        }
       }


     #852$x@ parsing here.....

SUBX:
   foreach my $xsubfield ($field->subfield('x')) {
    if ($xsubfield =~ /COPYID:[0-9]+/) { 
      next SUBX;
      }
    if ($xsubfield =~ /FUND: /) {
      next SUBX;
      }

      my @newsubfield = split /\@/, $xsubfield;
      my $bcount;

$bcount = 0;

      foreach $newsubfield(@newsubfield) {
       my $subsubfield = substr $newsubfield, 0,1;

        if ($subsubfield eq 'a' ) {
         $itype = substr $newsubfield, 1;
         $types{uc($itype)}++;
         }
#         else {
#         $types{'NONE'}++;
#         }

        if ($subsubfield eq 'j' ) {
         $jvalue = substr $newsubfield, 1;
         $j_sub{uc($jvalue)}++;
         }
#         else {
#         $j_sub{'NONE'}++;
#         }
        
        if ($bcount == 0) {   #limit to first @b subsubfield
         if ($subsubfield eq 'b' ) {
          $ccode = substr $newsubfield, 1;
          $collcodes{uc($ccode)}++;
          $bcount++;
          }
#         else {
#          $collcodes{'NONE'}++;
#          }
        }
      }
   }   
  }  
}

print "\n\n$i biblios read.\n$j items read.\n$no_852 biblios with no 852.\n$bad_852 852s missing barcode or itemtype.\n";
print "\nRESULTS BY ITEM TYPE\n";
foreach my $kee (sort keys %types){
   print $kee.":   ".$types{$kee}."\n";
}

print "\nRESULTS BY COLLECTION CODE\n";
foreach my $kee (sort keys %collcodes){
   print $kee.":   ".$collcodes{$kee}."\n";
}

print "\nRESULTS BY J subfield\n";
foreach my $kee (sort keys %j_sub){
   print $kee.":   ".$j_sub{$kee}."\n";
}

#print "\nRESULTS by H subfield\n";
#foreach my $kee (sort keys %h_sub){
#print $kee.":   ".$h_sub{$kee}."\n";
#}

exit if (!$create);

open $outfl,">$outfile_name";
print $outfl "# Item Types\n";
foreach my $kee (sort keys %types){
   print $outfl "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','$kee');\n";
}
print $outfl "# Collection Codes\n";
foreach my $kee (sort keys %collcodes){
   print $outfl "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','$kee');\n";
}

print $outfl "#callnumber\n";
foreach my $kee (sort keys %h_sub) {
   print $outfl "$kee\n";
}

close $outfl;

