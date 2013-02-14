#!/usr/bin/perl
#---------------------------------
# Copyright 2013 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett, based on some earlier work by Ian Walls
# 
#---------------------------------
#
# EXPECTS:
#   -biblionumber, and summary holdings in a CSV
#   -optional biblionumber map
#   -branchcode
#   -default username for inserts
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
my $default_branchcode  = $NULL_STRING;
my $default_librarian   = 'koha';
my $csv_delimiter       = 'comma';
my %biblio_map;
my %pattern_map;
my %vendor_map;
my $patternname;
my $period;
my $numbpattern;

GetOptions(
    'in=s'         => \$input_filename,
    'biblio_map=s' => \$biblio_map_filename,
    'def_branch=s' => \$default_branchcode,
    'def_user=s'   => \$default_librarian,
    'delimiter=s'  => \$csv_delimiter,
    'debug'        => \$debug,
    'update'       => \$doo_eet,
);

for my $var ($input_filename,$default_branchcode,$default_librarian) {
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

my $subscription_id;
my $problem_2 = 0;
my $serials = 0;
my $dbh = C4::Context->dbh();
my $sub_insert_sth = $dbh->prepare("INSERT INTO subscription (librarian,     branchcode, biblionumber,   notes,  
                                     location,   startdate, issuesatonce, manualhistory, serialsadditems, graceperiod, 
                                     monthlength, periodicity, numberingmethod, status, add1, every1, whenmorethan1, setto1,
                                     lastvalue1, setto2, lastvalue2, setto3, lastvalue3, numberpattern) 
                                    VALUES (?,?,?,'',NULL,NULL,1,0,0,0,12,32,'{X}',1,1,1,9999999,0,1,0,0,0,0,0)");
my $hist_insert_sth = $dbh->prepare("INSERT INTO subscriptionhistory 
                                     (biblionumber, subscriptionid, opacnote) 
                                     VALUES (?,?,?)");
my $get_subscripid_sth = $dbh->prepare("SELECT subscriptionid from subscription WHERE biblionumber = ?");

my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $delimiter{$csv_delimiter} });

open my $input_file,'<:utf8',$input_filename;

LINE:
while (my $line=$csv->getline($input_file)) {
   last LINE if ($debug && $i>2);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;
  
   my $biblionumber = $data[0];
   my $subscription_history = $data[1];


   # for Learning Access
   $subscription_history =~ s/^\d //;

   if (exists $biblio_map{$biblionumber}) {
      $biblionumber=$biblio_map{$biblionumber};
   }

   #check to see if subscription exists for this biblionumber
   $get_subscripid_sth->execute($biblionumber);
   my $rec=$get_subscripid_sth->fetchrow_hashref();
   $subscription_id = $rec->{'subscriptionid'};

   #no subscription then add subscription record and history record
   if ( (!$subscription_id ) && $doo_eet ) {
       $sub_insert_sth->execute($default_librarian, $default_branchcode, $biblionumber);
       my $addedsubscription_id = $dbh->last_insert_id(undef, undef, undef, undef);
       $subscription_id = $addedsubscription_id;
       $hist_insert_sth->execute($biblionumber, $subscription_id, $subscription_history);
       $written++;
   }
next LINE;

}
close $input_file;

print << "END_REPORT";

$i records read.
$written subscription records written.
$serials serial records added.
$problem records not loaded due to missing bibliographic records.
END_REPORT

exit;
