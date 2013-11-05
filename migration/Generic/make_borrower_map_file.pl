#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
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
use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Serials;
use MARC::Record;
use MARC::Field;
use MARC::Charset;

$|=1;
my $debug=0;
my $i=0;

my $field_to_map="";
my $outfilename="";

GetOptions(
    'field=s'       => \$field_to_map,
    'out=s'         => \$outfilename,
    'debug'         => \$debug,
);

if (($field_to_map eq q{}) || ($outfilename eq q{})){
   print "Something's missing.\n";
   exit;
}

my $written=0;

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT borrowernumber,$field_to_map FROM borrowers");
$sth->execute();

open my $out,'>',$outfilename;
RECORD:
while (my $row=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $i>9);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $thisfield = $row->{$field_to_map} || q{};
   my $thisborr = $row->{borrowernumber} || q{};
   print {$out} "$thisfield,$thisborr\n";
   $written++;
}

close $out;

print "\n$i records read from database.\n$written lines in output file.\n";

