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
#   -fields to use as userid and password
#   -tail length of password
#
# DOES:
#   -updates userid and password, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is set
#   -counts of users modified

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
use C4::Members;

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

my $user_field = 'NULL';
my $pass_field = 'NULL';
my $pass_length = 0;
my $smash_case = 0;

GetOptions(
    'user:s'     => \$user_field,
    'pass:s'     => \$pass_field,
    'pass_len:i' => \$pass_length,
    'drop_pass_case' => \$smash_case,
    'debug'      => \$debug,
    'update'     => \$doo_eet,

);

my $dbh=C4::Context->dbh();
my $sth = $dbh->prepare("SELECT borrowernumber,$user_field AS userfield,$pass_field AS passfield 
                         FROM borrowers WHERE flags=0 OR flags IS NULL");
$sth->execute();
USER:
while (my $this_user=$sth->fetchrow_hashref()) {
   last USER if ($debug && $written > 9);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my %newdata;
   $newdata{borrowernumber} = $this_user->{borrowernumber};
   if ($this_user->{userfield} && $this_user->{userfield} ne $NULL_STRING) {
      $newdata{userid} = $this_user->{userfield};
   }
   if ($this_user->{passfield} && $this_user->{passfield} ne $NULL_STRING) {
      my $new_pass = $this_user->{passfield};
      if ($pass_length > 0) {
         $new_pass = substr $this_user->{passfield}, -$pass_length; 
      }
      if ($smash_case) {
         $new_pass = lc $new_pass;
      }
      $newdata{password} = $new_pass;
   }
   next USER if (scalar(keys %newdata) == 1 );
   $debug and print Dumper(%newdata);
   if ($doo_eet) {
      ModMember(%newdata) 
   }
   $written++;
}

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
