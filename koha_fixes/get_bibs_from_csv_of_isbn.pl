#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
# Based on similar work by Catalyst, with many thanks
#
#---------------------------------

use Data::Dumper;
use Encode;
use Getopt::Long;
use Modern::Perl;
use ZOOM;
use Text::CSV_XS;
use MARC::Record;
use MARC::Field;
use MARC::Charset;
use MARC::File::XML ( BinaryEncoding => 'utf8' );
use Business::ISBN;
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
my $invalid_isbn = 0;


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

   my $isbn = Business::ISBN->new($data[0]);
   next RECORD if !$isbn;
   my $kee1;
   my $kee2;
   if ($isbn->is_valid) {
      my $isbn_10 = $isbn->as_isbn10();
      next RECORD if !$isbn_10;
      $isbn_10->fix_checksum();
      $kee1 = $isbn_10->{isbn};

      my $isbn_13 = $isbn->as_isbn13();
      next RECORD if !$isbn_13;
      $isbn_13->fix_checksum();
      $kee2 = $isbn_13->{isbn};
   }
   else {
      $invalid_isbn++;
      next RECORD;
   }
$debug and print "ISBN: $isbn  KEE1: $kee1 KEE2: $kee2\n";

   eval {
       $q  = " \@or \@or \@or \@attr 1=8 \"$kee1\" \@attr 1=7 \"$kee1\" \@attr 1=8 \"$kee2\" \@attr 1=7 \"$kee2\" ";
       $rs = $conn->search_pqf($q);

       $n = $rs->size();
       if ($n == 0){
           $debug and print "Not found: $isbn\n";
           print $missing "$isbn\n";
           $no_record = 1;
           $notfound++;
       } 
       else {
           $debug and print "Found: $isbn - $n records\n";
           $rec = $rs->record(0);
           $raw = $rec->raw();
       }
   };
   next RECORD if $no_record;
   if ($@) {
       print "Error on $data[0] - ", $@->code(), ": ", $@->message(), "\n";
       print $missing "$isbn\n";

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

print "\n";
say "$invalid_isbn records had bad ISBNs";
