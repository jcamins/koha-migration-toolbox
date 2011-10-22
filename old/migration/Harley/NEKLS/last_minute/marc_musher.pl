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
use MARC::File::USMARC;
use MARC::File::XML;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
use C4::Context;
$|=1;
my $debug=0;

my $infile_name = "";

GetOptions(
    'in=s'          => \$infile_name,
    'debug'         => \$debug,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
my $i=0;
my $dbh = C4::Context::dbh();
my $sth = $dbh->prepare("UPDATE biblioitems set marc=?, marcxml=? WHERE biblioitemnumber=?");

while () {
   last if ($debug and $i > 0);
   my $record = $batch->next();
   last unless ($record);
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   my $binumber = $record->subfield("999","d");
   $debug and print $binumber;
   $sth->execute($record->as_usmarc(),$record->as_xml_record("MARC21"),$binumber);
}

print "\n$i records read and imported.\n";
