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
use C4::Context;
use C4::Biblio;
$|=1;

my $output_file="";
my $missing_file="";
my $debug=0;
GetOptions(
   'out=s'    => \$output_file,
   'missing=s'   => \$missing_file,
   'debug'         => \$debug,
);

if (($output_file eq q{}) || ($missing_file eq q{})) {
   print "Something's missing.\n";
   exit;
}

MARC::Charset->ignore_errors(1);
MARC::Charset->assume_unicode(1);
MARC::File::XML->default_record_format('MARC21');

my $dbh          = C4::Context->dbh();


my $isbn_sth = $dbh->prepare("select biblionumber,isbn from biblioitems where isbn is not null and isbn <> '' ");
my $sth_bi   = $dbh->prepare("select marc from biblioitems where  biblionumber = ? ");

open my $outfl, '>:utf8', $output_file  or die "\nFail- open marcoutput: $!";
open my $missing, '>', $missing_file or die "Unable to open $missing_file: $!\n";

my $cnt;
my @marcdata;
my $i = 0;
my $found = 0;
my $notfound=0;


#my $conn = new ZOOM::Connection('nlnzcat.natlib.govt.nz:7190/Voyager');
#my $conn = new ZOOM::Connection('z3950.biblios.net:210/bibliographic');
my $conn = new ZOOM::Connection('lx2.loc.gov:210/LCDB');

$conn->option( preferredRecordSyntax => "usmarc" );

$isbn_sth->execute();

RECORD:
while (my $record = $isbn_sth->fetchrow_hashref) {
   my ($isbn, $biblionumber) = ($record->{isbn}, $record->{biblionumber});
   $i++;
   print ".";
   print "\r$i" unless $i % 100;

   chomp $isbn;

   my ( $q, $rs, $n, $rec, $raw );
   my $no_record = 0;
   $isbn =~ m/(.+?) /;
   my $kee = $1;
   if (!$kee){
      $kee = $isbn;
   }
$debug and print "ISBN: $isbn  KEE: $kee\n";

   eval {
       $q  = " \@or \@attr 1=8 \"$kee\" \@attr 1=7 \"$kee\" ";
       $rs = $conn->search_pqf($q);

       $n = $rs->size();

       if ($n == 0){
           $debug and print "Not found: $isbn\n";
           print $missing "$isbn\n";
           $no_record = 1;
           $notfound++;
       } else {
           $debug and print "Found: $isbn - $n records\n";
           $rec = $rs->record(0);
           $raw = $rec->raw();
       }
   };
   next RECORD if $no_record;
   if ($@) {
       print "Error on $isbn - ", $@->code(), ": ", $@->message(), "\n";
       print $missing "$isbn\n";

       $conn->destroy();
       sleep 2;
       #$conn = new ZOOM::Connection('nlnzcat.natlib.govt.nz:7190/Voyager');
       $conn = new ZOOM::Connection('z3950.biblios.net:210/bibliographic');
       $conn->option( preferredRecordSyntax => "usmarc" );
       next RECORD;
   }

   my $newmarc = new_from_usmarc MARC::Record($raw);
   my $newrecsize = substr($newmarc->leader(),0,5);

   $sth_bi->execute($biblionumber);
   my $thisrec=$sth_bi->fetchrow_hashref();
   my $oldmarc = new_from_usmarc MARC::Record($thisrec->{marc});
   my $oldrecsize = substr($oldmarc->leader(),0,5);

   if ($oldrecsize >= $newrecsize){
      $debug and print "Biblio: $biblionumber old rec ($oldrecsize) bigger than new ($newrecsize).  Skipping.\n";
      next RECORD;
   }

   $newmarc->field('020')->delete_subfield(code => 'a');
   $newmarc->insert_fields_ordered($oldmarc->field('020'));   
   print $outfl $newmarc->as_usmarc();
}

close $outfl;
close $missing;
