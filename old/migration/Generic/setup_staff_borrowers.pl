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
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use C4::Context;
$|=1;
my $debug=0;
my $doo_eet=0;

my $infile_name = "";

GetOptions(
   'debug' => \$debug,
   'update'=> \$doo_eet
);

#if (($infile_name eq '')){
# print "You're missing something.\n";
# exit;
#}

my $dbh=C4::Context->dbh();
my $i=0;
my @borrowers = qw /10 17 357 527 558 605 6721837 4413 5106 7017 11483 12327 13761/;
my @codes = qw /inventory items_batchdel items_batchmod label_creator manage_csv_profiles manage_staged_marc  moderate_comments moderate_tags rotating_collections schedule_tasks stage_marc_import view_system_logs/;

my $sth = $dbh->prepare("INSERT INTO user_permissions (borrowernumber,module_bit,code) VALUES (?,13,?)");
foreach my $borrower (@borrowers){
   foreach my $code (@codes){
      $i++;
      print ".";
      print "\r$i" unless ($i % 100);
      $debug and print "$borrower - $code\n";
      $doo_eet and $sth->execute($borrower,$code);
   }
}

print "\n$i records added.\n";
