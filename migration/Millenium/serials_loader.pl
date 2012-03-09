#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett, based on some earlier work by Ian Walls
# 
# Modification log: (initial and date)
#
#---------------------------------
#
# EXPECTS:
#   -III Serials export
#   -map from OCLC # in 001 to biblionumber
#   -map from vendor code to vendor id number
#   -branchcode
#
# DOES:
#   -inserts subscriptions and manual history, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be done, if --debug is set
#   -count of records read
#   -count of subscriptions created

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use C4::Context;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename      = $NULL_STRING;
my $biblio_map_filename = $NULL_STRING;
my $vendor_map_filename = $NULL_STRING;
my $default_branchcode  = $NULL_STRING;
my $default_librarian   = 'kohaadmin';
my $csv_delimiter       = 'pipe';
my %biblio_map;
my %vendor_map;

GetOptions(
    'in=s'         => \$input_filename,
    'biblio_map=s' => \$biblio_map_filename,
    'vendor_map=s' => \$vendor_map_filename,
    'def_branch=s' => \$default_branchcode,
    'def_user=s'   => \$default_librarian,
    'delimiter=s'  => \$csv_delimiter,
    'debug'        => \$debug,
    'update'       => \$doo_eet,

);

for my $var ($input_filename,$biblio_map_filename,$vendor_map_filename,$default_branchcode) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                );


print "Reading in biblio map file.\n";
if ($biblio_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$biblio_map_filename;
   while (my $line = $csv->getline($mapfile)) {
      my @data = @$line;
      $biblio_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

print "Reading in vendor map file.\n";
if ($biblio_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$vendor_map_filename;
   while (my $line = $csv->getline($mapfile)) {
      my @data = @$line;
      $vendor_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $problem_2 = 0;
my $dbh = C4::Context->dbh();
my $sub_insert_sth = $dbh->prepare("INSERT INTO subscription 
                                    (librarian,     branchcode, biblionumber,   notes, status, 
                                     internalnotes, location,   aqbooksellerid, startdate) 
                                    VALUES (?,?,?,?,?,?,?,?,?)");
my $hist_insert_sth = $dbh->prepare("INSERT INTO subscriptionhistory 
                                     (biblionumber, subscriptionid, recievedlist,librariannote) 
                                     VALUES (?,?,?,?)");
my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $delimiter{$csv_delimiter} });
open my $input_file,'<:utf8',$input_filename;
$csv->column_names($csv->getline($input_file));

LINE:
while (my $line=$csv->getline_hr($input_file)) {
   last LINE if ($debug && $i>5);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print Dumper($line);

   my $oclcnum = $line->{'OCLC #'};
   if ($oclcnum =~ /\-/) {
      ($oclcnum,undef) = split (/\-/, $oclcnum);
   }

   my $biblionumber = $biblio_map{$oclcnum};
   if (!$biblionumber) {
      print "OCLC $oclcnum not found!\n";
      $problem++;
      next LINE;
   }
   my $checkin  = $line->{'RECORD #(CHECKIN)'};
   my $location = $line->{'LOCATION'};
   my $identity = $line->{'IDENTITY'};
   my $lib_has  = $line->{'LIB. HAS(CHECKIN)'};
   my $note     = $line->{'NOTE(CHECKIN)'};
   my $vendor        = $vendor_map{$line->{'VENDOR'}} || $NULL_STRING;

   my $formatted_holdings = "$lib_has ($identity)";
   $formatted_holdings =~ s/\(\)//g;
   $formatted_holdings =~ s/\.\-/. /g;
   my $subscription_start_date = $lib_has;
   $subscription_start_date =~ s/^.*(\d{4}).*$/$1/;
   $subscription_start_date .= '-01-01';

   $debug and print "Biblio: $biblionumber CHKIN: $checkin HOLDS: $formatted_holdings START: $subscription_start_date\n";

   if ($doo_eet) {
      $sub_insert_sth->execute($default_librarian, $default_branchcode, $biblionumber, $checkin,                1, 
                               $note,              $location,           $vendor,       $subscription_start_date);
      my $subscription_id = $dbh->last_insert_id(undef, undef, undef, undef);
      if ($subscription_id) {
         $hist_insert_sth->execute($biblionumber, $subscription_id, $formatted_holdings, "Migrated from Millenium");
         $written++;
      }
      else {
         $problem_2++;
         next LINE;
      }
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to missing bibliographic records.
$problem_2 records not loaded due to failed INSERT in subscriptions table.
END_REPORT

exit;
