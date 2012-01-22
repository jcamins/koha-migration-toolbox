#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -WHERE clause for select
#   -which value is to be changed
#   -new value
#
# DOES:
#   -updates the value described, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of items modified
#   -details of what will be changed, if --debug is set

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Items;
$|=1;
my $debug = 0;
my $doo_eet = 0;
my $i=0;

my $where_clause    = q{};
my $field_to_change = q{};
my $new_value       = q{};

GetOptions(
   'where:s'  => \$where_clause,
   'field:s'  => \$field_to_change,
   'val:s'    => \$new_value,
   'debug'    => \$debug,
   'update'   => \$doo_eet,
);

if (($where_clause eq q{}) || ($field_to_change eq q{}) || ($new_value eq q{})){
   print "Something's missing.\n";
   exit;
}

if ($new_value eq 'NULL') {
   $new_value = undef;
}
my $written=0;
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT itemnumber,$field_to_change FROM items WHERE $where_clause");
$sth->execute();
RECORD:
while (my $row=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $i>0);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);

   $debug and print "($row->{itemnumber})  $field_to_change => $row->{$field_to_change}   changing to $new_value\n";

   if ($doo_eet){
      C4::Items::ModItem({ $field_to_change => $new_value },undef,$row->{'itemnumber'});
   }
   $written++;
}

print "\n\n$i records read.\n$written items updated.\n";
