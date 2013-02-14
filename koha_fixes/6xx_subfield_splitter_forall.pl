#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# - Joy Nelson
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -updates MARC  to split 650 tags, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be done, if --debug is set
#   -count of records considered
#   -count of records updated

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use MARC::Record;
use MARC::File::XML;
use MARC::Field;
use C4::Context;
use C4::Biblio;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $input_filename = $NULL_STRING;

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;
my $field;
my $x=0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT biblionumber,frameworkcode FROM biblio");
#my $marc_sth = $dbh->prepare("SELECT marcxml FROM biblioitems WHERE biblionumber = ?");
#my $item_sth=$dbh->prepare("SELECT biblionumber, frameworkcode FROM biblio join items using (biblionumber) WHERE items.barcode = ?");


my @tags;
my $tag;
my $rec2;

$sth->execute();
LINE:
while (my $bibs=$sth->fetchrow_hashref()) {
    last LINE if ($debug && $written >150000);
    $i++;
    print '.'    unless ($i % 10);
    print "\r$i" unless ($i % 100);

    $rec2 = C4::Biblio::GetMarcBiblio($bibs->{'biblionumber'});
    if (!$rec2) { #error; null biblio or trashed MARC
       $problem++;
       next LINE;
    }

    @tags=$rec2->field('6..');
    #$debug and print Dumper(@tag); #prints ALL 650 tags for bib
    foreach $tag (@tags) {
        my @fastaddsubfields=$tag->subfield("a") || "";
        #$debug and print Dumper(@fastaddsubfields); #this gets all a subfields
       foreach my $fastaddsubfield (@fastaddsubfields) { 
          if ($fastaddsubfield !~ m/.+\s\-\-\s.+/){
            next;
          }
          my @fastaddsubj = split(' -- ', $fastaddsubfield);
          $field=MARC::Field->new($tag->tag()," "," ","a" => $fastaddsubj[0]);
          $debug and print "biblionumber is $bibs->{'biblionumber'}\n";
          $debug and print "subject heading a is: $fastaddsubj[0]\n";

          $x=1;
          while ($x < (scalar @fastaddsubj)) {
              $field->add_subfields('x'=>$fastaddsubj[$x]);
              $debug and print "subject heading x is: $fastaddsubj[$x]\n";
              $x++;
          }
          $rec2->delete_field($tag);
          $rec2->insert_grouped_field($field);

     }

       if ($doo_eet){
#            $rec2->delete_field($tag);
#            $rec2->insert_grouped_field($field);
            C4::Biblio::ModBiblioMarc($rec2,$bibs->{'biblionumber'});
            $written++;
       }
     }
}
print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;
