#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# 
# Modification log: (initial and date)
#
#---------------------------------
#
# EXPECTS:
#   -serials issues export from Voyager
#   -map file for "Component ID" -> subscription ID
#
# DOES:
#   -inserts serial issues, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of records added
#   -count of problems

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
use C4::Serials;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = $NULL_STRING;
my $map_filename   = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'map=s'    => \$map_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename,$map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

print "Reading subscription map...\n";
my %subs_map;
if ($map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$map_filename;
   while (my $line = $csv->getline($map_file)) {
      my @data= @$line;
      $subs_map{$data[1]} = $data[0];
   }
   close $map_file;
}

print "Processing issues...\n";
my $dbh=C4::Context->dbh();
my $insert_sth = $dbh->prepare("INSERT INTO serial
                                (biblionumber, subscriptionid, serialseq, status, planneddate,
                                 publisheddate) 
                                VALUES (?,?,?,?,?,?)");
my $csv=Text::CSV_XS->new({ binary => 1 });
open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file));
LINE:
while (my $line=$csv->getline_hr($input_file)) {
   last LINE if ($debug && $i > 20);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   if (!exists $subs_map{$line->{COMPONENT_ID}}) {
      $debug and print "Component mapping not found\n";
      $problem++;
      next LINE;
   }
   my $subscription = GetSubscription($subs_map{$line->{COMPONENT_ID}});
   if (!$subscription) {
      $debug and print "Subscription not found\n";
      $problem++;
      next LINE;
   }
   my $status       = $line->{RECEIVED} ? 2 : 1;
   my $planneddate  = $line->{RECEIVED} ? _process_date($line->{RECEIPT_DATE}) : _process_date($line->{EXPECTED_DATE});
   my $publishdate  = _process_date($line->{EXPECTED_DATE});
   if ($line->{CHRON1} ne $NULL_STRING && $line->{CHRON2} ne $NULL_STRING && $line->{CHRON3} ne $NULL_STRING) {
      if ($line->{CHRON1} > 0 && $line->{CHRON2} > 0 && $line->{CHRON3} > 0) {
         $publishdate = sprintf "%d-%02d-%02d",$line->{CHRON1},$line->{CHRON2},$line->{CHRON3};
      }
   }
   elsif ($line->{CHRON1} ne $NULL_STRING && $line->{CHRON2} ne $NULL_STRING) {
      if ($line->{CHRON1} > 0 && $line->{CHRON2} > 0) {
         $publishdate = sprintf "%d-%02d-01",$line->{CHRON1},$line->{CHRON2};
      }
   }

   $debug and print "SUBS $subscription->{subscriptionid} STAT: $status ENUM $line->{ENUMCHRON} PLAN: $planneddate PUB: $publishdate\n";
   if ($doo_eet) {
      $insert_sth->execute($subscription->{biblionumber},$subscription->{subscriptionid},$line->{ENUMCHRON},$status,$planneddate,
                           $publishdate);
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;

sub _process_date {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq "";
   my ($month,$day,$year) = $datein =~ /(\d+).(\d+).(\d\d\d\d)/;
   if ($month && $day && $year) {
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
   }
   else {
      return undef;
   }
}

