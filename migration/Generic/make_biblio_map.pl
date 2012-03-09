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

my $tagfield="";
my $tagsubfield="";
my $outfilename="";

GetOptions(
    'tag=s'         => \$tagfield,
    'sub=s'         => \$tagsubfield,
    'out=s'         => \$outfilename,
    'debug'         => \$debug,
);

if (($tagfield eq q{}) || ($tagfield > 10 && $tagsubfield eq q{}) || ($outfilename eq q{})){
   print "Something's missing.\n";
   exit;
}

my $field_not_present=0;
my $written=0;

my $dbh=C4::Context->dbh();
my $dum=MARC::Charset->ignore_errors(1);
my $sth=$dbh->prepare("SELECT biblionumber FROM biblioitems");
my $marc_sth=$dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
$sth->execute();

open my $out,">",$outfilename;

RECORD:
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $marc_sth->execute($row->{biblionumber});
   my $rec = $marc_sth->fetchrow_hashref();
   my $marc;
   eval {$marc = MARC::Record->new_from_usmarc($rec->{marc}); };
   if ($@){
      print "bogus record skipped\n";
      next RECORD;
   }
   my $field;
   my $data;
   if ($tagfield < 10){
      my $tagg = $marc->field($tagfield);
      if ($tagg){
         $field = $tagg->data();
      }
   }
   else{
      $field = $marc->subfield($tagfield,$tagsubfield);
   }
   if (!$field){
      $field_not_present++;
      next RECORD;
   }
   $field =~ s/\"/'/g;
   if ($field =~ m/\,/){
      $field = '"'.$field.'"';
   }
   print {$out} "$field,$row->{biblionumber}\n";
   $written++;
}

close $out;

print "\n$i records read from database.\n$written lines in output file.\n";
print "$field_not_present records not considered due to missing or invalid field.\n\n";

