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
my $modified=0;
my $added=0;
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');

my $sth=$dbh->prepare("SELECT biblionumber from biblioitems");
$sth->execute();
my $marc_sth = $dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
my $upd_sth = $dbh->prepare("UPDATE biblioitems SET itemtype=? WHERE biblionumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber,enumchron FROM items where biblionumber=? AND itype='PERIODICAL' LIMIT 1");
RECORD:
while (my $thisrec=$sth->fetchrow_hashref()){
   last RECORD if ($debug && ($added >0));
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
   my $enumstring = "Holdings Summary:<br><ul>";
   my %headers = ( a => "Print holdings: ",
                   b => "Microfilm holdings: ",
                   c => "Note: ",
                   g => "Note: ",
                   z => "Note: ",
                 );
   foreach my $curfield ($rec->field('996')){
      foreach my $subfield ($curfield->subfields()){
         my ($code,$val) = @$subfield;
         if (!$headers{$code}){
            print "BAD CODE: $thisrec->{biblionumber}    $code\n";
         }
         $enumstring .= '<li>'.$headers{$code}.$val.'</li>';
      }
   }
   $enumstring .= '</ul>';

   next RECORD if ($enumstring eq "Holdings Summary:<br><ul></ul>");

   $item_sth->execute($thisrec->{biblionumber});
   my $itemrec = $item_sth->fetchrow_hashref();

   if (!$itemrec->{itemnumber}){
      if ($doo_eet){
         C4::Items::AddItem({ cn_source      => 'lcc',
                              homebranch     => 'MAIN',
                              holdingbranch  => 'MAIN',
                              location       => 'PERIODICAL',
                              itemcallnumber => 'PER',
                              itype          => 'PERIODICAL',
                              barcode        => $thisrec->{biblionumber}.'-1001',
                              enumchron      => $enumstring,
                            }, $thisrec->{biblionumber});
         print "\nNo item found on biblio: $thisrec->{biblionumber}, adding.\n";
      }
      $added++;
      next RECORD;
   }

   if ($itemrec->{enumchron}){
      next RECORD if ($enumstring eq $itemrec->{enumchron});
      if ($itemrec->{enumchron} ne q{}){
         print "\nITEM ALREADY MARKED DIFFERENTLY on biblio: $thisrec->{biblionumber}\n";
         next RECORD;
      }
   }

   $debug and print "\nBIBLIO: $thisrec->{biblionumber}  ITEM: $itemrec->{itemnumber}  VAL: $enumstring\n";
   if ($doo_eet){
      C4::Items::ModItem({enumchron => $enumstring},undef,$itemrec->{itemnumber});
   }
   $modified++;
}
print "\n\n$i records examined.\n$modified records modified.\n$added items created.\n";
