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
#   -nothing
#
# DOES:
#   -updates borrower addresses to handle splitting them into proper fields, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is set
#   -count of borrowers examined
#   -count of addresses modified

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


GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $break_tag = 0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT * FROM borrowers");
$sth->execute();
BORROWER:
while (my $borrower=$sth->fetchrow_hashref()) {
   last BORROWER if ($debug && $break_tag);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   if ($borrower->{address} =~ m/\$/) {
      my ($address,$address2,$city,$state,$zip) = _split_address($borrower->{address});
      $debug and print "Borrower $borrower->{borrowernumber}:   $borrower->{address}\n";
      $debug and print "$address~\n$address2~\n$city~\n$state~\n$zip~\n----------\n";
      if ($doo_eet) {
         ModMember( borrowernumber => $borrower->{borrowernumber},
                    address        => $address,
                    address2       => $address2,
                    city           => $city,
                    state          => $state,
                    zipcode        => $zip
                  );
      }
      $written++;
   }
   if ($borrower->{B_address} =~ m/\$/) {
      my ($address,$address2,$city,$state,$zip) = _split_address($borrower->{B_address});
      $debug and print "Borrower $borrower->{borrowernumber}:   $borrower->{B_address}\n";
      $debug and print "$address~\n$address2~\n$city~\n$state~\n$zip~\n----------\n";
      if ($doo_eet) {
         ModMember( borrowernumber => $borrower->{borrowernumber},
                    B_address      => $address,
                    B_address2     => $address2,
                    B_city         => $city,
                    B_state        => $state,
                    B_zipcode      => $zip
                  );
      }
      $written++;
   }
}

print << "END_REPORT";

$i borrowers examined.
$written addresses modified written.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;

sub _split_address {
   my $address_in = shift;
   my $address_out = $NULL_STRING;
   my $address2_out = $NULL_STRING;
   my $city_out = $NULL_STRING;
   my $state_out = $NULL_STRING;
   my $zip_out = $NULL_STRING;
   $address_in =~ s/^\$+//;
   $address_in =~ s/\$+$//;
   my @lines = split /\$/, $address_in;
   my $city_line = pop(@lines);
   if (scalar (@lines) == 1) {
      $address_out = $lines[0];
   }
   elsif (scalar (@lines) == 2) {
      $address_out = $lines[0];
      $address2_out = $lines[1];
   }
   elsif (scalar (@lines) == 3) {
      $address_out = $lines[0] . ' -- ' . $lines[1];
      $address2_out = $lines[2];
      $break_tag = 1;
   }
   else {
      return ($address_in, '', '', '', '');
   }
   my @city_terms = split ' ',$city_line;
   if (scalar @city_terms < 3) {
      return ($address_out, $address2_out, $city_line, '', '');
   }
   $zip_out = pop(@city_terms);
   $state_out = pop(@city_terms);
   $city_out = join (' ',@city_terms);
   $city_out =~ s/\,$//;
   return ($address_out, $address2_out, $city_out, $state_out, $zip_out);
}
