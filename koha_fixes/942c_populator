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
use Text::CSV;
use MARC::Charset;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;
my $itype_map_name="";
my %itype_map;

GetOptions(
    'map=s'         => \$itype_map_name,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

#if (($branch eq '')){
#  print "Something's missing.\n";
#  exit;
#}

if ($itype_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$itype_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $itype_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $dbh=C4::Context->dbh();
my $i=0;
my $modified=0;
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');

my $sth=$dbh->prepare("SELECT biblioitems.biblionumber AS biblionumber,frameworkcode from biblioitems
                    JOIN biblio USING (biblionumber)");
$sth->execute();
my $marc_sth = $dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
my $item_sth = $dbh->prepare("SELECT itype FROM items WHERE biblionumber=? LIMIT 1");
my $upd_sth = $dbh->prepare("UPDATE biblioitems SET itemtype=? WHERE biblionumber=?");
while (my $thisrec=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $marc_sth->execute($thisrec->{'biblionumber'});
   my $marcrec = $marc_sth->fetchrow_hashref();
   my $rec;
   eval{ $rec = MARC::Record::new_from_usmarc($marcrec->{'marc'});};
   if ($@){
      print "\n Error in biblio $thisrec->{'biblionumber'}\n";
      next;
   }
   my $curval = $rec->subfield("942","c") || "";
   $item_sth->execute($thisrec->{'biblionumber'});
   my $itmrec=$item_sth->fetchrow_hashref();
   my $val = $itmrec->{'itype'} || "";
   $val = $itype_map{$val} if (exists ($itype_map{$val}));
   if ($val ne $curval){
      $debug and print "Biblio: $thisrec->{'biblionumber'}  Old: $curval New: $val\n";
      foreach my $dump ($rec->field("942")){
         $rec->delete_field($dump);
      }
      my $field=MARC::Field->new("942"," "," ","c" => $val);
      $rec->insert_grouped_field($field);
      if ($doo_eet){
         $upd_sth->execute($val,$thisrec->{'biblionumber'});
         C4::Biblio::ModBiblioMarc($rec,$thisrec->{'biblionumber'}, $thisrec->{'frameworkcode'});
      }
      $modified++;
   }
}
print "\n\n$i records examined.\n$modified records modified.\n";

