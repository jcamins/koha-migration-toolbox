#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
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
use DBI;
use MARC::Charset;
use MARC::Record;
use MARC::Field;

$|=1;
my $debug=0;

my $db = "";
my $user = "";
my $pass = "";
my $infile_name = "";
my $branch = "";
my $branch_map_name = "";
my %branch_map;
my $shelfloc_map_name = "";
my %shelfloc_map;
my $itype_map_name = "";
my %itype_map;
my $collcode_map_name = "";
my %collcode_map;
my $patron_map_name = "";
my %patron_map;
my $patron_code_map_name = "";
my %patron_code_map;
my $tag_itypes_str = "";
my %tag_itypes;
my $skip_biblio = 0;

GetOptions(
    'database=s'        => \$db,
    'user=s'            => \$user,
    'pass=s'            => \$pass,
    'branch=s'          => \$branch,
    'branch_map=s'      => \$branch_map_name,
    'shelfloc_map=s'    => \$shelfloc_map_name,
    'itype_map=s'       => \$itype_map_name,
    'collcode_map=s'    => \$collcode_map_name,
    'patron_map=s'      => \$patron_map_name,
    'patron_code_map=s' => \$patron_code_map_name,
    'tag_itypes=s'      => \$tag_itypes_str,
    'skip_biblio'       => \$skip_biblio,
    'debug'             => \$debug,
);

if (($branch eq '') || ($db eq '')){
  print "Something's missing.\n";
  exit;
}

if ($branch_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$branch_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($shelfloc_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$shelfloc_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $shelfloc_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($itype_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$itype_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $itype_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($collcode_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$collcode_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $collcode_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($patron_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$patron_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $patron_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($patron_code_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$patron_code_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $patron_code_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($tag_itypes_str){
   my @tags = split(/,/,$tag_itypes_str);
   foreach my $tag (@tags){
      $tag_itypes{$tag} = 1;
   }
}

my $dbh = DBI->connect("dbi:mysql:$db:localhost:3306",$user,$pass);

#
#  BIBLIOGRAPHIC INFORMATION SECTION
#

exit if ($skip_biblio);

print "Dumping bibliographic records:\n";
open my $out,">itypes.txt";
my $sth = $dbh->prepare("SELECT athena_copies.*,type_name from athena_copies 
                      LEFT JOIN athena_copy_types on (athena_copies.copy_type_oid = athena_copy_types.copy_type_oid)
                      ");
my $i=0;

$sth->execute();
while (my $row = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $barcode = $row->{'copy_id'};
   my $itemtype = uc($row->{'type_name'});
   if (exists $itype_map{$itemtype}){
      $itemtype=$itype_map{$itemtype};
   }
   print $out 'UPDATE items SET itype="'.$itemtype.'" WHERE BARCODE = "'.$barcode.'";';
   print $out "\n";
}
close $out;

exit;

