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
use Encode;
use Getopt::Long;
use Win32::ODBC;
$|=1;
my $debug=0;

my $dsn_name = "";

GetOptions(
    'dsn=s'         => \$dsn_name,
    'debug'         => \$debug,
);

if ($dsn_name eq ''){
  print "Something's missing.\n";
  exit;
}

my $i=0;
my @tables = qw/ CIRC_CLASS             CIRC_STATUSES
                 CIRC_STATUSES_SUB      CIRC_TRANS
                 ITEMS                  ITEM_TYPES 
                 LOCATIONS              PATRON_CLAIMED_RETURNED_ITEMS
                 PATRON_FINES_FOR_ITEMS PATRON_HOLDS_ON_ITEMS  
                 PATRON_LOST_ITEMS      PATRON_ON_LOAN_ITEMS
                 PATRONS                SERIAL_BOUND_ITEMS
                 SERIAL_COPIES          SERIAL_ITEMS
                 SERIAL_ROUTING         SERIAL_ROUTING_PATRONS
                 TEMP_BOOKS             TEMP_TIEM_TYPES
                 TRANS_TYPES /;
my $db = Win32::ODBC->new($dsn_name);
if (!$db){
   print "Could not connect to ODBC data source $dsn_name.\n";
   exit;
}

TABLE:
for my $this_table (@tables){
   print "Dumping $this_table.\n";
   if ($db->Sql("SELECT * from $this_table")){
      print "SQL failed on table $this_table:  $db->error().\n";
      $db->close();
      next TABLE;
   }
   $i++;

   my @fields=sort($db->FieldNames());
   my $j=0;
   open my $out,">:utf8",$this_table.".csv";

   for my $k (0..scalar(@fields)-1){
      print $out $fields[$k].',';
   }
   print $out "\n";

   while ($db->FetchRow()){
      $j++;
      print ".";
      print "\r$j" unless ($j % 100);
      my %data = $db->DataHash();
      for my $k (0..scalar(@fields)-1){
         if ($data{$fields[$k]}){
            $data{$fields[$k]} =~ s/\"/'/g;
            if ($data{$fields[$k]} =~ /,/){
               print $out '"'.$data{$fields[$k]}.'"';
            }
            else{
               print $out $data{$fields[$k]};
            }
         }
         print $out ",";
      }
      print $out "\n";
   }
   close $out;
   print "\n$j records exported.\n";
}

$db->Close();
