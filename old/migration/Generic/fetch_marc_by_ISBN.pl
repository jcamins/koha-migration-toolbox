#!/usr/bin/perl -w
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
use Net::Z3950::ZOOM;
use ZOOM;
use MARC::Record;
$|=1;
my $debug=0;

my $infile_name="";
my $outfile_name="";
my $errfile_name="";

GetOptions(
    'in=s'     => \$infile_name,
    'out=s'    => \$outfile_name,
    'err=s'    => \$errfile_name,
    'debug'    => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($errfile_name eq '')){
   print "Something's missing.\n";
   exit;
}

open my $in,"<$infile_name";
open my $out,">:utf8",$outfile_name;
open my $err,">$errfile_name";
my $i=0;
my $bibs_out=0;
my $nonefound=0;
my $multiples=0;

my $conn = ZOOM::Connection->new('zsrv.library.northwestern.edu',11090,  databaseName => 'voyager' ,preferredRecordSyntax => "usmarc");
if (!defined($conn)){
   print "Can't connect to the server for some reason!\n";
   exit;
}
while (my $line=readline($in)){
#   sleep 1;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   chomp $line;
   while (length($line)<10){
     $line = "0".$line;
   }
   $debug and print "SEARCHING: $line      ";
   my $search = $conn->search_pqf("\@attr 1=7 $line");
   my $outputcount = $search->size();
   $debug and print "SIZE: $outputcount    ";
   if (!$outputcount){
      $debug and print "NONEFOUND\n";
      print $err $line."\n";
      $nonefound++;
      next;
   }
   if ($outputcount >1){
      $debug and print "MULTIFOUND\n";
      print "\nMultiples found for $line\n"; 
      $multiples++;
   }
   for (my $j=1; $j<=$outputcount; $j++){
      $debug and print "~";
      my $thisrec = $search->record($j-1);
      my $marcrec = MARC::Record::new_from_usmarc($thisrec->raw());
      print $out $marcrec->as_usmarc();
      $bibs_out++;
   }
}
close $in;
close $out;
close $err;
print "\n\n$i records read.\n";
print "$bibs_out biblios written.\n";
print "$nonefound records found zero hits.\n";
print "$multiples records found more than one hit.\n";
