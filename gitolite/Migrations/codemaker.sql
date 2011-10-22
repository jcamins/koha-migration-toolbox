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
$|=1;
my $debug=0;

my $branch_name = "";
my $types_name = "";
my $coll_name = "";
my $loc_name = "";
my $outfile_name = "";

GetOptions(
    'out=s'         => \$outfile_name,
    'branch=s'      => \$branch_name,
    'type=s'        => \$types_name,
    'coll=s'        => \$coll_name,
    'loc=s'         => \$loc_name,
    'debug'         => \$debug,
);

if (($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

open my $out,">$outfile_name";

if ($branch_name){
   print $out "#\n# BRANCHES\n#\n";
   my $csv = Text::CSV->new();
   open my $in,"<$branch_name";
   my $headerrow = $csv->getline($in);
   my @fields = @$headerrow;
   my $queryhead = "INSERT INTO branches (";
   for (my $j=0;$j<scalar(@fields);$j++){
      $queryhead .= $fields[$j] .",";
   }
   $queryhead =~ s/,$//;
   $queryhead .= ") VALUES (";
   my $querytail = ");\n";
   while (my $row = $csv->getline($in)){
      my @data=@$row;
      my $querymiddle = "";
      for (my $j=0;$j<scalar(@fields);$j++){
         $querymiddle .= "'".$data[$j]."',";
      }
      $querymiddle =~ s/,$//;
      print $out $queryhead.$querymiddle.$querytail;
   }
   close $in;
}

if ($types_name){
   print $out "#\n# TYPES\n#\n";
   my $csv = Text::CSV->new();
   open my $in,"<$types_name";
   my $headerrow = $csv->getline($in);
   my @fields = @$headerrow;
   my $queryhead = "INSERT INTO itemtypes (";
   for (my $j=0;$j<scalar(@fields);$j++){
      $queryhead .= $fields[$j] .",";
   }
   $queryhead =~ s/,$//;
   $queryhead .= ") VALUES (";
   my $querytail = ");\n";
   while (my $row = $csv->getline($in)){
      my @data=@$row;
      my $querymiddle = "";
      for (my $j=0;$j<scalar(@fields);$j++){
         $querymiddle .= "'".$data[$j]."',";
      }
      $querymiddle =~ s/,$//;
      print $out $queryhead.$querymiddle.$querytail;
   }
   close $in;
}

if ($coll_name){
   print $out "#\n# COLLECTION CODES\n#\n";
   my $csv = Text::CSV->new();
   open my $in,"<$coll_name";
   my $headerrow = $csv->getline($in);
   my @fields = @$headerrow;
   my $queryhead = "INSERT INTO authorised_values (category,";
   for (my $j=0;$j<scalar(@fields);$j++){
      $queryhead .= $fields[$j] .",";
   }
   $queryhead =~ s/,$//;
   $queryhead .= ") VALUES ('CCODE',";
   my $querytail = ");\n";
   while (my $row = $csv->getline($in)){
      my @data=@$row;
      my $querymiddle = "";
      for (my $j=0;$j<scalar(@fields);$j++){
         $querymiddle .= "'".$data[$j]."',";
      }
      $querymiddle =~ s/,$//;
      print $out $queryhead.$querymiddle.$querytail;
   }
   close $in;
}

if ($loc_name){
   print $out "#\n# LOCATION CODES\n#\n";
   my $csv = Text::CSV->new();
   open my $in,"<$loc_name";
   my $headerrow = $csv->getline($in);
   my @fields = @$headerrow;
   my $queryhead = "INSERT INTO authorised_values (category,";
   for (my $j=0;$j<scalar(@fields);$j++){
      $queryhead .= $fields[$j] .",";
   }
   $queryhead =~ s/,$//;
   $queryhead .= ") VALUES ('LOC',";
   my $querytail = ");\n";
   while (my $row = $csv->getline($in)){
      my @data=@$row;
      my $querymiddle = "";
      for (my $j=0;$j<scalar(@fields);$j++){
         $querymiddle .= "'".$data[$j]."',";
      }
      $querymiddle =~ s/,$//;
      print $out $queryhead.$querymiddle.$querytail;
   }
   close $in;
}

close $out;
