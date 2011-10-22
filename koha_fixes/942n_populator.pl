#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -Joy Nelson, edited
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

my $itype_name="";
my $val=0;

GetOptions(
    'itype=s'       => \$itype_name,
    '942n_value=i'   => \$val,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

if (($itype_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $dbh=C4::Context->dbh();
my $i=0;
my $modified=0;

my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');

my $sth=$dbh->prepare("SELECT DISTINCT biblionumber,frameworkcode from items 
                       JOIN biblio USING (biblionumber)
                       WHERE itype=?");
$sth->execute( $itype_name );
my $marc_sth = $dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");

RECORD:
while (my $thisrec=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $modified > 0);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $marc_sth->execute($thisrec->{biblionumber});
   my $marcrec = $marc_sth->fetchrow_hashref();
   my $rec;
   eval{ $rec = MARC::Record::new_from_usmarc($marcrec->{'marc'});};
   if ($@){
      print "\n Error in biblio $thisrec->{'biblionumber'}\n";
      next;
   }
   my $field=$rec->field('942');
   if ($field){
      my $curval = $field->subfield("n") || "";
      if ($curval ne $val){
         $debug and print "Biblio: $thisrec->{'biblionumber'}  Old: $curval New: $val\n";
         $field->update('n' => $val);
         if ($doo_eet){
            C4::Biblio::ModBiblioMarc($rec,$thisrec->{'biblionumber'}, $thisrec->{'frameworkcode'});
         }
         $modified++;
      }
   }
   else{
      my $field=MARC::Field->new("942"," "," ","n" => $val);
      $rec->insert_grouped_field($field);
      if ($doo_eet){
         C4::Biblio::ModBiblioMarc($rec,$thisrec->{'biblionumber'}, $thisrec->{'frameworkcode'});
      }
      $modified++;
   }
}
print "\n\n$i records examined.\n$modified records modified.\n";

