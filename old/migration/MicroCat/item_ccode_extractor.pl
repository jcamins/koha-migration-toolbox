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
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;

my $infile_name = "";
my $force_loc = "";

GetOptions(
    'in=s'          => \$infile_name,
    'debug'         => \$debug,
    'force_loc=s    => \$force_loc,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $dbh= C4::Context->dbh();
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
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

while () {
   last if ($debug and $written > 0);
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);

   foreach my $field ($record->field("090")){
      my $collcode;
      my @barcodearray;
      my @copyarray;
      my @volarray;
      $j++;

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

      $collcode = uc($field->subfield('f'));

      for (my $k=0;$k<scalar(@barcodearray);$k++){
         if ($collcode){
            $item_sth->execute($barcodearray[$k]);
            my $hash = $item_sth->fetchrow_hashref();
            my $itemnum = $hash->{'itemnumber'};
            C4::Items::Moditem({ ccode = $collcode },undef,$itemnum);
            if ($force_loc){
               C4::Items::ModItem({ location = $force_loc },undef,$itemnum);
            }
            $written++;
            $debug and print "Item: $itemnum   Coll: $collcode";
         }
      }
   }
}
 
close $infl;
close $outfl;

print "\n\n$i biblios read.\n$j items read.\n$written items modified.\n";
