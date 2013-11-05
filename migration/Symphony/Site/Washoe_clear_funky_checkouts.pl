#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -updates bibs/items to Washoe specs, if --update is specified
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is specified
#   -count of bibs/items modified

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
use C4::Items;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $written = 0;
my $problem = 0;


GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

#for my $var ($input_filename) {
#   croak ("You're missing something") if $var eq $NULL_STRING;
#}

my $dbh                  = C4::Context->dbh();
my $sth;
$i       = 0;
my $issues_deleted = 0;
$j = 0;
my $sel_sth = $dbh->prepare("select borrowernumber,firstname,branchcode from borrowers where firstname like '%display%'");
my $iss_sth = $dbh->prepare("select itemnumber from issues where borrowernumber = ?");
my $del_sth = $dbh->prepare("delete from issues where itemnumber =?");
$sel_sth->execute();

while (my $borr = $sel_sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $iss_sth->execute($borr->{borrowernumber});
   while (my $issue = $iss_sth->fetchrow_hashref()) {
      $debug and print "deleting issue $issue->{itemnumber}. ";
      if ($doo_eet) {
         $del_sth->execute($issue->{itemnumber});
      }
      $issues_deleted++;
      my $newloc;
      if ($borr->{branchcode} ne 'SO' && $borr->{branchcode} ne 'RN') {
         $newloc = 'DISPLAY'.$borr->{branchcode};
      }
      elsif ($borr->{branchcode} eq 'RN') {
         $newloc = $borr->{firstname} eq 'DISPLAY'              ? 'DISPLAYRN'  :
                   $borr->{firstname} eq 'DISPLAY - CHILDRENS'  ? 'DISPRNCHLD' :
                   $borr->{firstname} eq 'DISPLAY - YOUNG ADUL' ? 'DISPRNYA'   : 'DISPRNYA';
      }
      else {
         $newloc = $borr->{firstname} eq 'VALLEYS - DISPLAY'      ? 'DISPLAYSO'  :
                   $borr->{firstname} eq 'VALLEYS - DISPLAY YPL'  ? 'DISPSOYPL'  : 'DISPLAYSO';
      }
      $debug and print "setting location to $newloc.\n"; 
      if ($doo_eet) {
         ModItem({location => $newloc}, undef, $issue->{itemnumber});
      }
      $j++;
   }
}
 
print "\n\n"; 
print "$i borrowers read.\n$issues_deleted issues dropped.  $j items modified.\n";

exit;

