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
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;

GetOptions(
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

#if (($branch eq '')){
#  print "Something's missing.\n";
#  exit;
#}

my $dbh=C4::Context->dbh();
my $i=0;
my $added=0;
my $modified=0;
my $haltnow=0;
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');

my $sth=$dbh->prepare("SELECT biblionumber ,frameworkcode from biblio");
$sth->execute();
my $marc_sth = $dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
my $upd_sth = $dbh->prepare("UPDATE biblioitems SET itemtype=? WHERE biblionumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items where biblionumber=?");
RECORD:
while (my $thisrec=$sth->fetchrow_hashref()){
   last RECORD if ($debug && $haltnow);
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
   my $touched=0;
   if (!$rec->field('092')){
      my $copyfld = $rec->field('082');
      if ($copyfld){
         my $newtag = MARC::Field->new('092',$copyfld->indicator(1),$copyfld->indicator(2),
            'a'=>$copyfld->subfield('a'),'b'=>$copyfld->subfield('b'));
         $rec->insert_fields_ordered($newtag);
         $touched=1;
      }
   }
   foreach my $curfield ($rec->field('082')){
      $rec->delete_field($curfield);
      $touched=1;
   }   
   foreach my $curfield ($rec->field('050')){
      $rec->delete_field($curfield);
      $touched=1;
   }   
   foreach my $curfield ($rec->field('080')){
      $rec->delete_field($curfield);
      $touched=1;
   }   
   foreach my $curfield ($rec->field('090')){
      $rec->delete_field($curfield);
      $touched=1;
   }   
   foreach my $curfield ($rec->field('096')){
      $rec->delete_field($curfield);
      $touched=1;
   }   
   if ($touched){
      if ($doo_eet){
         C4::Biblio::ModBiblioMarc($rec,$thisrec->{'biblionumber'}, $thisrec->{'frameworkcode'});
      }
      $modified++;
   }

   my $test = $rec->subfield('533','c') || "" ;

   next RECORD if ($test !~ m/^ebrary/);

   $item_sth->execute($thisrec->{biblionumber});
   my $itemrec = $item_sth->fetchrow_hashref();

   if (!$itemrec->{itemnumber}){
      if ($doo_eet){
         C4::Items::AddItem({ cn_source      => 'ddc',
                              homebranch     => 'GRISWOLD',
                              holdingbranch  => 'GRISWOLD',
                              itemcallnumber => 'ONLINE',
                              itype          => 'EBOOK',
                              barcode        => $thisrec->{biblionumber}.'-1001',
                            }, $thisrec->{biblionumber});
      }
      $added++;
         $debug and $haltnow=1;
   }
}
print "\n\n$i records examined.\n$modified records modified.\n$added items created.\n";
