#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# This script is intended to ingest a MARC-formatted patron file from 
# VTLS Virtua, and write an output file in a form that can be 
# fed to ByWater's General Purpose Database Table Loader script.
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Getopt::Long;
use Text::CSV;
use C4::Context;

my $infile_name = "";
my $table_name = "";
my $borrowercol = "";
my $itemcol = "";
my $bibliocol = "";

GetOptions(
    'in=s'     => \$infile_name,
    'table=s'  => \$table_name,
    'borr=s'   => \$borrowercol,
    'item=s'   => \$itemcol,
    'bib=s'    => \$bibliocol,
);

if (($infile_name eq '') || ($table_name eq '')){
    print << 'ENDUSAGE';

Usage:  table_loader --in=<infile> --table=<kohatable> [--borr=<column>] [--item=<column>]

<infile>     A pipe-formatted data file, with header row containing fieldnames.

<kohatable>  A Koha table to push the data into.

<column>     The column header that points to borrower (--borr) or item (--item) barcodes,
             for conversion to Koha borrowernumber or itemnumber.

ENDUSAGE
exit;
}

my $csv=Text::CSV->new();
my $dbh=C4::Context->dbh();
my $j=0;
my $exceptcount=0;
open my $io,"<$infile_name";
my $headerline = $csv->getline($io);
my @fields=@$headerline;
while (my $line=$csv->getline($io)){
   $j++;
   #print ".";
   #print "\r$j" unless ($j % 100);
   my @data = @$line;
   my $querystr = "INSERT INTO $table_name (";
   my $exception = 0;
   for (my $i=0;$i<scalar(@data);$i++){
      if ($fields[$i] eq "ignore"){
         next;
      }
      if ($fields[$i] eq $borrowercol){
         $querystr .= "borrowernumber,";
         next;
      }
      if ($fields[$i] eq $bibliocol){
         $querystr .= "biblionumber,";
         next;
      }
      if ($fields[$i] eq $itemcol){
         $querystr .= "itemnumber,";
         next;
      }
      if ($data[$i] ne ""){
         $querystr .= $fields[$i].",";
      }
   }
   $querystr =~ s/,$//;
   $querystr .= ") VALUES (";
   for (my $i=0;$i<scalar(@fields);$i++){
      if ($fields[$i] eq "ignore"){
         next;
      }
      if ($fields[$i] eq $borrowercol){
         my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = '$data[$i]';");
         $convertq->execute();
         my $rec=$convertq->fetchrow_hashref();
         if ($rec->{'borrowernumber'}){
            $querystr .= $rec->{'borrowernumber'}.",";
         }
         else {
            $exception = 1;
         }
         next;
      } 
      if ($fields[$i] eq $bibliocol){
         my $convertq = $dbh->prepare("SELECT biblionumber FROM items WHERE barcode = '$data[$i]';");
         $convertq->execute();
         my $rec=$convertq->fetchrow_hashref();
         if ($rec->{'biblionumber'}){
            $querystr .= $rec->{'biblionumber'}.",";
         }
         else {
            $exception = 1;
         }
         next;
      } 
      if ($fields[$i] eq $itemcol){
         if ($data[$i]){
            my $convertq = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode = '$data[$i]';");
            $convertq->execute();
            my $rec=$convertq->fetchrow_hashref();
            if ($rec->{'itemnumber'}){
               $querystr .= $rec->{'itemnumber'}.",";
            }
            else {
               $exception = 1;
            }
            next;
         }
         else{
            $querystr .= "NULL,";
         }
      } 
      if ($fields[$i] =~ /date/){
         if (length($data[$i]) == 8){
           $data[$i] =~ s/(\d{4})(\d{2})(\d{2})/$1-$2-$3/;
         }
      }
      if ($data[$i] ne ""){
         $querystr .= '"'.$data[$i].'",';
      }
   }
   $querystr =~ s/,$//;
   $querystr .= ");";
   if (!$exception){
      my $sth = $dbh->prepare($querystr);
      $sth->execute();
   }
   else {
      $exceptcount++;
      print "EXCEPTION:  \n";
      for (my $i=0;$i<scalar(@fields);$i++){
         print $fields[$i].":  ".$data[$i]."\n";
      }
      print "--------------------------------------------\n";
   }
}
print "$j records processed.  $exceptcount exceptions.\n";
