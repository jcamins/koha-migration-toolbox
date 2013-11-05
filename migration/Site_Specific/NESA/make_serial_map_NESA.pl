#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#  modified for NESA 10-4-2012 jen
#---------------------------------

use Data::Dumper;
use Getopt::Long;
use Modern::Perl;
use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Serials;
use MARC::Record;
use MARC::Field;
use MARC::Charset;
use Text::CSV_XS;

$|=1;
my $debug=0;
my $i=0;

my $tagfield="";
my $tagsubfield="";
my $tagfield2="";
my $tagsubfield2="";
my $outfilename="";
my $whereclause="";
my $patternmapfile="";
my %patternmap;

GetOptions(
    'tag=s'         => \$tagfield,
    'sub=s'         => \$tagsubfield,
    'tag2=s'        => \$tagfield2,
    'sub2=s'        => \$tagsubfield2,
    'out=s'         => \$outfilename,
    'where=s'       => \$whereclause,
    'debug'         => \$debug,
    'map=s'           => \$patternmapfile,
);

if (($tagfield eq q{}) || ($tagfield > 10 && $tagsubfield eq q{}) || ($outfilename eq q{})){
   print "Something's missing.\n";
   exit;
}

if ($patternmapfile){
   my $csv = Text::CSV_XS->new();
   open my $mapfile,"<$patternmapfile";
   while (my $row = $csv->getline($mapfile)){
      my @data=@$row;
      $patternmap{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $field_not_present=0;
my $field2_not_present=0;
my $written=0;

my $dbh=C4::Context->dbh();
my $dum=MARC::Charset->ignore_errors(1);
my $query = "SELECT biblionumber FROM biblioitems ";
if ($whereclause ne '') {
   $query .= " WHERE $whereclause";
}
my $marc_sth=$dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
my $sth=$dbh->prepare($query);
$sth->execute();

open my $out,">",$outfilename;

RECORD:
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $marc_sth->execute($row->{biblionumber});
   my $rec = $marc_sth->fetchrow_hashref();
   $debug and print Dumper($rec);
   my $marc;
   eval {$marc = MARC::Record->new_from_usmarc($rec->{marc}); };
   if ($@){
      print "bogus record skipped\n";
      next RECORD;
   }
#   $debug and print Dumper($marc);
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
   $debug and say "$field";
   if (!$field){
      $field_not_present++;
      next RECORD;
   }
   $field =~ s/\"/'/g;
   if ($field =~ m/\,/){
      $field = '"'.$field.'"';
   }
   my $field2;
   my $data2;
   if ($tagfield2 < 10){
      my $tagg2 = $marc->field($tagfield2);
      if ($tagg2){
         $field2 = $tagg2->data();
      }
   }
   else{
      $field2 = $marc->subfield($tagfield2,$tagsubfield2);
   }
   $debug and say "$field2";
   if (!$field2){
      $field2_not_present++;
      next RECORD;
   }

   if (exists $patternmap{$field2}){
            $debug and warn "Swapping cat $field2 to $patternmap{$field2}.";
            $field2 = $patternmap{$field2};
   } 

#   $field2 =~ s/\"/'/g;
#   if ($field2 =~ m/\,/){
#      $field2 = '"'.$field2.'"';
#   }


   print {$out} "$field,$field2\n";
   $written++;
}

close $out;

print "\n$i records read from database.\n$written lines in output file.\n";
print "$field_not_present records not considered due to missing or invalid field.\n\n";

