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
#   -nothing
#
# DOES:
#   -inserts a static 540$a into every bib record
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -number of records written

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use MARC::Charset;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;


GetOptions(
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

my $dbh=C4::Context->dbh();

my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');

my $sth=$dbh->prepare("SELECT DISTINCT biblionumber,frameworkcode from biblioitems 
                       JOIN biblio USING (biblionumber)");
                        
my $marc_sth = $dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
$sth->execute();
RECORD:
while (my $thisrec=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $written > 0);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   my $marcrec = GetMarcBiblio($thisrec->{biblionumber});;
   if (!$marcrec) {
      print "problem with record $thisrec->{biblionumber}\n";
      $problem++;
   } 

   my $val = "Copyright restrictions apply. Permission to publish, quote, or reproduce must be secured from the Shasta Historical Society. The reproduction of some materials may be restricted by terms of gift, purchase agreements, donor restrictions, privacy and publicity rights, licensing and trademarks. Responsibility for any use rests exclusively with the user.";

   my $field=MARC::Field->new("540"," "," ","a" => $val);
   $marcrec->insert_grouped_field($field);
   if ($doo_eet){
      C4::Biblio::ModBiblioMarc($marcrec,$thisrec->{'biblionumber'}, $thisrec->{'frameworkcode'});
   }
   $written++;
}

print << "END_REPORT";

$i records read.
$written records modified.
$problem records not modified due to problems.
END_REPORT

