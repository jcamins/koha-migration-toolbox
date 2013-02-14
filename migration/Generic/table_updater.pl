#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use autodie;
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use C4::Context;
$|=1;

my $infile_name = "";
my $table_name = "";
my $borrowercol = "XXX";
my $itemcol = "YYY";
my $bibliocol = "ZZZ";
my $alternate = undef;
my $debug=0;
my $doo_eet=0;
my $barlength = 0;
my $barprefix = '';

GetOptions(
    'in=s'     => \$infile_name,
    'table=s'  => \$table_name,
    'borr=s'   => \$borrowercol,
    'alt=s'    => \$alternate,
    'item=s'   => \$itemcol,
    'bib=s'    => \$bibliocol,
    'barprefix=s'  => \$barprefix,
    'barlength=i'  => \$barlength,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq '') || ($table_name eq '')){
   print "Something's missing.\n";
   exit;
}

my $csv=Text::CSV->new({ binary => 1 });
my $dbh=C4::Context->dbh();
my $j=0;
my $exceptcount=0;
open my $io,"<$infile_name";
my $headerline = $csv->getline($io);
my @fields=@$headerline;
$debug and print Dumper(@fields);
while (my $line=$csv->getline($io)){
   $debug and last if ($j>180); 
   $j++;
   print ".";
   print "\r$j" unless ($j % 100);
   my @data = @$line;
   $debug and print Dumper(@data);
   my $querystr = "UPDATE $table_name SET ";
   my $exception = 0;
   for (my $i=1;$i<scalar(@data);$i++){
      next if ($fields[$i] eq "");
      if ($fields[$i] eq "ignore"){
         next;
      }
      if ($fields[$i] eq $borrowercol){
         $querystr .= "borrowernumber=";
         next;
      }
      if ($fields[$i] eq $bibliocol){
         $querystr .= "biblionumber=";
         next;
      }
      if ($fields[$i] eq $itemcol){
         $querystr .= "itemnumber=";
         next;
      }
      if (($data[$i] ne "") && ($fields[$i] ne "suppress")){
         $querystr .= $fields[$i]."=";
      }

      if ($fields[$i] eq $borrowercol){
         if ($barprefix ne '' || $barlength > 0) {
            my $curbar = $data[$i];
            my $prefixlen = length($barprefix);
            if (($barlength > 0) && (length($curbar) <= ($barlength-$prefixlen))) {
               my $fixlen = $barlength - $prefixlen;
               while (length ($curbar) < $fixlen) {
                  $curbar = '0'.$curbar;
               }
               $curbar = $barprefix . $curbar;
            }
            $data[$i] = $curbar;
         }

         my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = '$data[$i]';");
         $convertq->execute();
         my $rec=$convertq->fetchrow_hashref();
         my $borr=$rec->{'borrowernumber'} || $alternate;
         if ($borr){
            $querystr .= $borr.",";
         }
         else {
            $exception = "No Borrower";
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
            $exception = "No Biblio";
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
               $exception = "No Item";
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
      $debug and print "I: $i\n";
      if (($data[$i] ne "") && ($fields[$i] ne "suppress")){
         $data[$i] =~ s/\"/\\"/g;
         $querystr .= '"'.$data[$i].'",';
      }
   }
   $querystr =~ s/,$//;
   $querystr .= " WHERE $fields[0] = '$data[0]'";
   $debug and print $querystr."\n";
   if (!$exception){
      my $sth = $dbh->prepare($querystr);
      if ($doo_eet){
        $sth->execute();
      }
   }
   else {
      $exceptcount++;
      print "\nEXCEPTION:  $exception\n";
      for (my $i=0;$i<scalar(@fields);$i++){
         print $fields[$i].":  ".$data[$i]."\n";
      }
      print "--------------------------------------------\n";
   }
}
print "\n\n$j records processed.  $exceptcount exceptions.\n";
