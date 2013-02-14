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
#   -updates MARC and MARCXML to split 650 tags, if --update is set
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
    'in=s'     => \$input_filename,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $dbh = C4::Context->dbh();
#my $sth = $dbh->prepare("SELECT biblionumber,frameworkcode FROM biblio where biblionumber = ?");
#my $marc_sth = $dbh->prepare("SELECT marcxml FROM biblioitems WHERE biblionumber = ?");
#my $item_sth=$dbh->prepare("SELECT biblionumber, frameworkcode FROM biblio join items using (biblionumber) WHERE items.barcode = ?");
my $csv=Text::CSV_XS->new({binary => 1});
open my $input_file,'<',$input_filename;

LINE:
while (my $line=$csv->getline($input_file)) {
    last LINE if ($debug && $written >15000);
    $i++;
    print '.'    unless ($i % 10);
    print "\r$i" unless ($i % 100);

    my @data = @$line;
#    $item_sth->execute($data[0]);
#
#print "this barcode: $data[0]\n";  #this prints
#
#    my $rec=$item_sth->fetchrow_hashref(); 
#    if ($rec->{'biblionumber'}){
#      $debug and print "Biblio: $rec->{'biblionumber'}\n"; #this prints
#    }
#    else {
#      print "NO Biblio record found\n"; #this prints
#      next LINE;
#    }
#
#    $marc_sth->execute($rec->{biblionumber});
#    my $marcrec = $marc_sth->fetchrow_hashref();
#    
#    my $rec2;
#    $rec2 = MARC::Record::new_from_usmarc($marcrec->{'marc'});
#$debug and print Dumper($rec2);
#    eval{ $rec2 = MARC::Record::new_from_usmarc($marcrec->{'marc'});};
#      if ($@){
#         $problem++;
#         print "\n bad marc for  $data[0]\n";
#         next LINE;
#      }
    my $item = C4::Items::GetItem(undef,$data[0]);
    if (!$item) { #error; that barcode isn't found 
       $problem++;
       next LINE; 
    }
    my $rec2 = C4::Biblio::GetMarcBiblio($item->{biblionumber});
    if (!$rec2) { #error; null biblio or trashed MARC
       $problem++;
       next LINE;
    }

      foreach my $tag ($rec2->field('6..')){
#$debug and print Dumper($tag);
        my $fastaddsubf=$tag->subfield("a") || "";

if ($fastaddsubf !~ m/.+\-\-/){
next LINE;
}
        my @fastaddsubj = split(' -- ', $fastaddsubf);
#$debug and print Dumper(@fastaddsubj);
        $field=MARC::Field->new($tag->tag()," "," ","a" => $fastaddsubj[0]);
#$debug and print Dumper($field);
$debug and print "subject heading a is: $fastaddsubj[0]\n";

        $x=1;
        while ($x < (scalar @fastaddsubj)) {
           $field->add_subfields('x'=>$fastaddsubj[$x]);
$debug and print "subject heading x is: $fastaddsubj[$x]\n";
           $x++;
        }
 
        if ($doo_eet){
            $rec2->delete_field($tag);

            $rec2->insert_grouped_field($field);
            C4::Biblio::ModBiblioMarc($rec2,$item->{'biblionumber'});
        }
        $written++;
      }
}
print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;
