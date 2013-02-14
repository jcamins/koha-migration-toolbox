#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -modified on 7/5/2012 to search for ISSN
# Based on similar work by Catalyst, with many thanks
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Encode;
use Getopt::Long;
use ZOOM;
use Text::CSV_XS;
use MARC::Record;
use MARC::Field;
use MARC::Charset;
use MARC::File::XML ( BinaryEncoding => 'utf8' );
use Business::ISSN;
$|=1;

my $incoming_file="";
my $output_file="";
my $missing_file="";
my $debug=0;
my $server = "lx2.loc.gov";
my $port = 210;
my $database = "LCDB";

my @data;
my @line;
my $line;

GetOptions(
   'in=s'      => \$incoming_file,
   'out=s'     => \$output_file,
   'server=s'  => \$server,
   'port=s'    => \$port,
   'database=s' => \$database,
   'missing=s' => \$missing_file,
   'debug'     => \$debug,
);

if (($incoming_file eq q{}) || ($output_file eq q{}) || ($missing_file eq q{})) {
   print "Something's missing.\n";
   exit;
}

my $csv = Text::CSV_XS->new();
open my $infl,"<",$incoming_file;

MARC::Charset->ignore_errors(1);
MARC::Charset->assume_unicode(1);
MARC::File::XML->default_record_format('MARC21');

open my $outfl, '>:utf8', $output_file  or die "\nFail- open marcoutput: $!";
open my $missing, '>', $missing_file or die "Unable to open $missing_file: $!\n";

my $cnt;
my @marcdata;
my $i = 0;
my $found = 0;
my $notfound=0;


#my $conn = new ZOOM::Connection('nlnzcat.natlib.govt.nz:7190/Voyager');
#my $conn = new ZOOM::Connection('z3950.biblios.net:210/bibliographic');
my $conn = new ZOOM::Connection("$server:$port/$database");

$conn->option( preferredRecordSyntax => "usmarc" );

RECORD:
while  ($line=$csv->getline($infl)) {
   @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;

   my ( $q, $rs, $n, $rec, $raw );
   my $no_record = 0;

   my $issn = Business::ISSN->new($data[0]);
   next RECORD if !$issn;
   my $kee1;
   my $kee2;
   if ($issn->is_valid) {
      my $issn_str = $issn->as_string();
      next RECORD if !$issn_str;
      $kee1 = $issn_str;
      $kee2=$data[0];
   }
   else {
      next RECORD;
   }
$debug and print "ISSN: $data[0]  KEE1: $kee1 KEE2: $kee2\n";

   eval {
       $q  = " \@or \@or \@or \@attr 1=8 \"$kee1\" \@attr 1=7 \"$kee1\" \@attr 1=8 \"$kee2\" \@attr 1=7 \"$kee2\" ";
       $rs = $conn->search_pqf($q);

       $n = $rs->size();
       if ($n == 0){
           $debug and print "Not found: $data[0]\n";
           print $missing "$data[0]\n";
           $no_record = 1;
           $notfound++;
       } 
       else {
           $debug and print "Found: $data[0] - $n records\n";
           $rec = $rs->record(0);
           $raw = $rec->raw();
       }
   };
   next RECORD if $no_record;
   if ($@) {
       print "Error on $data[0] - ", $@->code(), ": ", $@->message(), "\n";
       print $missing "$data[0]\n";

       $conn->destroy();
       sleep 2;
       my $connection_ok = 0;
       while (!$connection_ok) {
          eval {
             $conn = new ZOOM::Connection("$server:$port/$database");
          };
          if (!$@) {
             $connection_ok = 1;
          }
       }
       $conn->option( preferredRecordSyntax => "usmarc" );
       next RECORD;
   }

   my $newmarc = new_from_usmarc MARC::Record($raw);

   print $outfl $newmarc->as_usmarc();
}

close $outfl;
close $missing;
