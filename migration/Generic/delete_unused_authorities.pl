#!/usr/bin/perl
#---------------------------------
# Copyright 2013 ByWater Solutions
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
#   -nothing
#
# DOES:
#   -drops authorities that are not in use, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of authorities considered
#   -count of authorities deleted
#   -what would be done, if --debug is set

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;

use C4::Context;
use C4::AuthoritiesMarc;
use C4::Search;

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


GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT authid FROM auth_header ORDER BY authid");
$sth->execute();
RECORD:
while (my $auth=$sth->fetchrow_array()) {
   last RECORD if ($debug and $written > 10);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $query='an='.$auth;
   my ($err,$res,$used) = C4::Search::SimpleSearch($query,0,10);
   if (defined $err) {
      $used = 0;
   }
   $debug and print "$auth: $used";
   if ($used > 0) {
      $debug and say '';
      #$debug and last RECORD;
      next RECORD;
   }
   else {
      $debug and say '--DELETING!';
      if ($doo_eet) {
         DelAuthority($auth);
      }
      $written++;
   }
}

print << "END_REPORT";

$i records checked.
$written records deleted.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
