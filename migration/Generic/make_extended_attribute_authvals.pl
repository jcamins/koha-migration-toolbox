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
#   -Extended attribute to make a list out of
#
# DOES:
#   -Creates authorized value list, and attaches it to the attribute, if --update is given
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is present
#   -counts of values added to list

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
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $attribute = $NULL_STRING;

GetOptions(
    'attribute=s' => \$attribute,
    'debug'       => \$debug,
    'update'      => \$doo_eet,
);

for my $var ($attribute) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $dbh = C4::Context->dbh();
my $find_values_sth     = $dbh->prepare("SELECT DISTINCT attribute FROM borrower_attributes WHERE code=? ORDER BY attribute");
my $insert_value_sth    = $dbh->prepare("INSERT INTO authorised_values (category,authorised_value,lib) VALUES (?,?,?)");
my $attribute_setup_sth = $dbh->prepare("UPDATE borrower_attribute_types SET authorised_value_category=? WHERE code=?");
my $codelist            = 'E_'.$attribute;
$find_values_sth->execute($attribute);
LINE:
while (my $line=$find_values_sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);


   $debug and print "CODE: $codelist  VAL $line->{attribute}\n";
   if ($doo_eet) {
      $insert_value_sth->execute($codelist,$line->{attribute},$line->{attribute});
   }
   $written++
}

if ($doo_eet) {
   $attribute_setup_sth->execute($codelist,$attribute);
} 

print << "END_REPORT";

$written values written.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
