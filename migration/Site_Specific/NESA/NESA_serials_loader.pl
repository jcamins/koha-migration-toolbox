#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett, based on some earlier work by Ian Walls
# 
# Modification log: (initial and date)
#    Joy Nelson - modified for NESA 9/24/2012
#
#---------------------------------
#
# EXPECTS:
#   -CyberTools Serials export
#   -map from 998$c (Cybertools bib number) to biblionumber
#   -branchcode
#
# DOES:
#   -inserts subscriptions and manual history, if --update is set
#   -inserts into serial table
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
my $pattern_map_filename = $NULL_STRING;
my $default_branchcode  = $NULL_STRING;
my $default_librarian   = 'koha';
my $csv_delimiter       = ',';
my %biblio_map;
my %pattern_map;
my %vendor_map;
my $patternname;
my $period;
my $numbpattern;

GetOptions(
    'in=s'         => \$input_filename,
    'biblio_map=s' => \$biblio_map_filename,
    'pattern_map=s'=> \$pattern_map_filename,
    'def_branch=s' => \$default_branchcode,
    'def_user=s'   => \$default_librarian,
    'delimiter=s'  => \$csv_delimiter,
    'debug'        => \$debug,
    'update'       => \$doo_eet,
);

for my $var ($input_filename,$biblio_map_filename,$default_branchcode) {
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
print "Reading in serial pattern map file.\n";
if ($pattern_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$pattern_map_filename;
   while (my $line = $csv->getline($mapfile)) {
      my @data = @$line;
      $pattern_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $subscription_id;
my $problem_2 = 0;
my $serials = 0;
my $dbh = C4::Context->dbh();
my $sub_insert_sth = $dbh->prepare("INSERT INTO subscription (librarian,     branchcode, biblionumber,   notes,  
                                     location,   startdate, issuesatonce, manualhistory, serialsadditems, graceperiod, 
                                     monthlength, periodicity, numberingmethod, status, add1, every1, whenmorethan1, setto1,
                                     lastvalue1, setto2, lastvalue2, setto3, lastvalue3, numberpattern) 
                                    VALUES (?,?,?,?,?,?,1,0,0,0,12,?,'{X}',1,1,1,9999999,0,1,0,0,0,0,?)");
my $hist_insert_sth = $dbh->prepare("INSERT INTO subscriptionhistory 
                                     (biblionumber, subscriptionid, librariannote) 
                                     VALUES (?,?,?)");
my $get_subscripid_sth = $dbh->prepare("SELECT subscriptionid from subscription WHERE biblionumber = ?");
my $upd_subhistory_sth = $dbh->prepare("UPDATE subscriptionhistory set recievedlist = concat(recievedlist,'; ',?) 
                                               where subscriptionid =?");
my $add_serial_sth = $dbh->prepare("INSERT into serial (biblionumber, subscriptionid, serialseq, status, notes,
                                           publisheddate) VALUES (?,?,?,?,?,?)");


my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $delimiter{$csv_delimiter} });

open my $input_file,'<:utf8',$input_filename;
$csv->column_names($csv->getline($input_file));

LINE:
while (my $line=$csv->getline_hr($input_file)) {
   last LINE if ($debug && $i>2);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
#   $debug and print Dumper($line);

   my $ct_num = $line->{'ctbibid'};
$debug and print "ct number is: $ct_num\n";
   my $biblionumber = $biblio_map{$ct_num};
$debug and print "map value is $biblio_map{$ct_num}\n";
   if (!$biblionumber) {
      print "CyberTools biblio: $ct_num not found in the map!\n";
      $problem++;
      next LINE;
   }

   if (exists $pattern_map{$ct_num}){
      $patternname = $pattern_map{$ct_num};
      $debug and print "$patternname\n";
   }
   else {
      $patternname = 'Irregular';
   }

#set periodicity and numbering pattern
   if ($patternname eq 'Quarterly' ){
      $period = 8;
      $numbpattern = 0;
   }
   elsif ($patternname eq 'Bimonthly'){
      $period = 6;
      $numbpattern = 1;
   }
   elsif ($patternname eq 'Triannually'){
      $period = 13;
      $numbpattern = 0;
   }
   elsif ($patternname eq 'Semiannual'){
      $period = 9;
      $numbpattern = 1;
   }
   elsif ($patternname eq 'Tenperyear'){
      $period = 32;
      $numbpattern = 1;
   }
   elsif ($patternname eq 'Eightperyear'){
      $period = 32;
      $numbpattern = 1;
   }
   elsif ($patternname eq 'Monthly'){
      $period = 5;
      $numbpattern = 1;
   }
   elsif ($patternname eq 'Irregular'){
      $period =32;
      $numbpattern = 0;
   }
   elsif ($patternname eq 'Semimonthly'){
      $period = 4;
      $numbpattern = 1;
   }
   elsif ($patternname eq 'Yearly'){
      $period = 10;
      $numbpattern = 0;
   }
   $debug and print "$period, $numbpattern\n";
   
   my $note     =  $line->{'notes'}  || " ";
   my $location = $line->{'location'};
   my $lib_has  = $line->{'has'};
   my $sub_start = $line->{'year'};
   my $volume = $line->{'volume'} . ':' . $line->{'issue'};
   my $published_date = $line->{'month'} . $sub_start;
$debug and print "$line->{'addlpart'}  ,  $line->{'supplement'}    ,  $line->{'boundvolumes'}\n";
   my $serial_note = $line->{'addlpart'} . $line->{'supplement'} . $line->{'boundvolumes'};

   my $subscription_start_date = $sub_start;
   $subscription_start_date =~ m/^.*(\d{4}).*$/;
   if ($1) {
      $subscription_start_date = $1 . '-01-01';
   }
   else {
      $subscription_start_date = undef;
   }

   $debug and print "Biblio: $biblionumber START: $subscription_start_date\n";

   #check to see if subscription exists for this biblionumber
   $get_subscripid_sth->execute($biblionumber);
   my $rec=$get_subscripid_sth->fetchrow_hashref();
   $subscription_id = $rec->{'subscriptionid'};

   if ($subscription_id) {
     print "$subscription_id\n";
   }
   else {
     print "no subscription id\n"; 
   }

   #no subscription then add subscription record and history record
   if ( (!$subscription_id ) && $doo_eet ) {
       $sub_insert_sth->execute($default_librarian, $default_branchcode, $biblionumber, $note, 
                               $location,           $subscription_start_date, $period, $numbpattern);
       my $addedsubscription_id = $dbh->last_insert_id(undef, undef, undef, undef);
       $subscription_id = $addedsubscription_id;
       $hist_insert_sth->execute($biblionumber, $subscription_id, "Migrated from CyberTools");
       $written++;
   }

#fill out subhistory received list and add serial record
    if ($doo_eet) {
    $upd_subhistory_sth ->execute($volume, $subscription_id);
    $add_serial_sth ->execute($biblionumber, $subscription_id, $volume, 2, $serial_note, $published_date);
    $serials++;
    }
next LINE;

}
close $input_file;

print << "END_REPORT";

$i records read.
$written subscription records written.
$serials serial records added.
$problem records not loaded due to missing bibliographic records.
$problem_2 records not loaded due to failed INSERT in subscriptions table.
END_REPORT

exit;
