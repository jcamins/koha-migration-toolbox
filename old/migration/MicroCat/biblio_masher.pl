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
use Getopt::Long;
use Parse::Range qw(parse_range);
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $drop_noitem = 0;
my $branch = "";
my $type="";

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'debug'         => \$debug,
    'drop_noitem'   => \$drop_noitem,
    'branch=s'      => \$branch,
    'type=s'        => \$type,
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
my $no_090=0;

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

   if (!$record->field("090")){
       $no_090++;
       next if ($drop_noitem);  
       foreach my $dumpfield($record->field('9..')){
          $record->delete_field($dumpfield);
       }
       print $outfl $record->as_usmarc();
       $written++;
   }

   foreach my $field ($record->field("090")){
      my $homebranch;
      my $holdbranch;
      my $itype;
      my $itemcall;
      my $enumchron;
      my $collcode;
      my @barcodearray;
      my @copyarray;
      my @volarray;
      $j++;
      my $copies = $field->subfield('c');
      if ($copies){
	@copyarray = parse_range($copies);
      }
      my $vols = $field->subfield('d');
      if ($vols){
	@volarray = parse_range($vols);
      }

      my $barcode = $field->subfield('e');
      $barcode = $j if (!$barcode);
      if (($barcode !~ /\-/)){
         @barcodearray = split(/,/,$barcode);
      }
      elsif ($barcode !~ /\,/){
         $barcode =~ /^(\d)-/;
         $barcodearray[0] = $1;
         $barcodearray[1] = $barcodearray[0]+1;
      }
      else {   #DARK ARTS--handle the *ONE* Brandon case where we can get here!
         @barcodearray = qw(14235 14235a 14235b 20815);
         @volarray = qw(1 2 3 4);
      }

      $collcode = $field->subfield('f');
      $itemcall = $field->subfield('a');
      $homebranch = $branch;
      $holdbranch = $branch;
      $itype = $type;

      for (my $k=0;$k<scalar(@barcodearray);$k++){
         my $itmtag=MARC::Field->new("952"," "," ",
           "p" => $barcodearray[$k],
           "a" => $homebranch,
           "b" => $holdbranch,
           "o" => $itemcall,
           "y" => $itype,
           "2" => "nlm",
         );
         $itmtag->update( "t" => "c. ".$copyarray[$k] ) if ($copyarray[$k]);
         $itmtag->update( "h" => "v. ".$volarray[$k] ) if ($volarray[$k]);
   
         $record->insert_grouped_field($itmtag);
      }
   }

   foreach my $dumpfield($record->field('090')){
      $record->delete_field($dumpfield);
   }
 
   print $outfl $record->as_usmarc();
   $written++;
}
 
close $infl;
close $outfl;

print "\n\n$i biblios read.\n$j items read.\n$written biblios written.\n$no_090 biblios with no 090.\n";
