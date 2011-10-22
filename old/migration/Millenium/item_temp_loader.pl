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
use C4::Context;
$|=1;
my $debug=0;

my $infile_name = "";
my $dropdata = 0;

GetOptions(
    'in=s'            => \$infile_name,
    'dropfirst'       => \$dropdata,
    'debug'           => \$debug,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $dbh = C4::Context->dbh();
if ($dropdata){
   $dbh->do("DROP TABLE IF EXISTS temp_iii_items");
}

my $csv = Text::CSV->new();
open my $in,"<$infile_name";
my $headerline = $csv->getline($in);
my @fields = @$headerline;
my $querystr = "CREATE TABLE IF NOT EXISTS temp_iii_items (id INTEGER AUTO_INCREMENT PRIMARY KEY, ";
for (my $k=0;$k<scalar(@fields);$k++){
   next if ($fields[$k] eq "ignore");
   if ($fields[$k] eq "barcode"){
      $querystr .= "barcode TEXT(50) NOT NULL, ";
   }
   elsif ($fields[$k] eq "biblio"){
      $querystr .= "biblio TEXT(20) NOT NULL, ";
   }
   else{
      $querystr .= $fields[$k]." TEXT(200), ";
   }
}
$querystr =~ s/, $//;
$querystr .= ") ENGINE=INNODB;";

$dbh->do($querystr);

my $i=0;
my $j=0;
while (my $line = $csv->getline($in)){
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($data[1] =~ /^b[0-9]/){
      splice(@data,1,1);
   }
   my $query = "INSERT INTO temp_iii_items (";
   my $values = "";
   my $baditem = 0;
   for (my $k=0;$k<scalar(@fields);$k++){
      $debug and last if ($i > 200);
      next if ($fields[$k] eq "ignore");
      $data[$k] = "" if ($data[$k] eq "-");
      $data[$k] = "" if ($data[$k] eq "  -  -  ");
      $data[$k] =~ s/ //g if ($fields[$k] eq "barcode");

      $baditem =1 if (($fields[$k] eq "biblio" and $data[$k] eq "") or ($fields[$k] eq "barcode" and $data[$k] eq ""));
      if ($fields[$k] eq "barcode" && $data[$k] =~ / -- /){
         print "\nDoubled barcode:  $data[$k]\n";
      }
      if ($data[$k] ne ""){
         $query .= $fields[$k].",";
         $values .= '"'.$data[$k].'",';
      }
   }
   $query =~ s/,$//;
   $values =~ s/,$//;
   $query .= ") VALUES ($values);";
   if (!$baditem){
      $dbh->do($query);
      $debug and print $query."\n";
      $j++;
   }
}

close $in;

print "\n\n$i lines read.\n$j items inserted.\n";
exit;

