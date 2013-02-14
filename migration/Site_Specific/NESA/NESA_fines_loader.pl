#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -Joy Nelson
#
#---------------------------------

use strict;
use warnings;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Accounts;
$|=1;

my $infile_name = "";
my $borrowercol = "";
my $itemcol = "";
my $borrbarlength = 0;
my $borrbarprefix = "";
my $debug= 0;
my $doo_eet=0;

GetOptions(
    'in=s'     => \$infile_name,
    'borr=s'   => \$borrowercol,
    'item=s'   => \$itemcol,
#    'b_barlength=i' => \$borrbarlength,
#    'b_barprefix=s' => \$borrbarprefix,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq '')){
   print "Something's missing.\n";
   exit;
}

my $csv=Text::CSV_XS->new( {binary=>1} );
my $dbh=C4::Context->dbh();
my $j=0;
my $exceptcount=0;
open my $io,"<$infile_name";
my $headerline = $csv->getline($io);
my @fields=@$headerline;
while (my $line=$csv->getline($io)){
   my $nextaccntno = "";

   $j++;
   print ".";
   print "\r$j" unless ($j % 100);
   my @data = @$line;
   my $querystr = "INSERT INTO accountlines (";
   my $exception = 0;
   for (my $i=0;$i<scalar(@data);$i++){
     if ($fields[$i]){
      if ($fields[$i] eq "ignore"){
         next;
      }
      if ($fields[$i] eq $borrowercol){
         $querystr .= "borrowernumber,";
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
   }
   $querystr .= "accountno) VALUES (";
   for (my $i=0;$i<scalar(@fields);$i++){
      if ($fields[$i] eq "ignore"){
         next;
      }
      if ($fields[$i] eq $borrowercol){
         if ($borrbarprefix ne '' || $borrbarlength > 0) {
            my $curbar = $data[$i];
           $debug and print $curbar."\n";
            my $prefixlen = length($borrbarprefix);
            if (($borrbarlength > 0) && (length($curbar) <= ($borrbarlength-$prefixlen))) {
               my $fixlen = $borrbarlength - $prefixlen;
               while (length ($curbar) < $fixlen) {
                  $debug and print "zero!";
                  $curbar = '0'.$curbar;
               }
               $curbar = $borrbarprefix . $curbar;
            }
       $debug and print $curbar."\n";
            $data[$i] = $curbar;
         }

         $data[$i] =~ s/ //g;
         my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE sort1 = '$data[$i]';");
         $convertq->execute();
         my $rec=$convertq->fetchrow_hashref();
         if ($rec->{'borrowernumber'}){
            $querystr .= $rec->{'borrowernumber'}.",";
            $nextaccntno = C4::Accounts::getnextacctno($rec->{'borrowernumber'});
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
      if ($data[$i] ne ""){
         $querystr .= '"'.$data[$i].'",';
      }
   }
   $querystr .= "$nextaccntno);";

   $debug and warn $querystr;
   if (!$exception){
      my $sth = $dbh->prepare($querystr);
      $sth->execute() if ($doo_eet);
   }
   else {
      $exceptcount++;
      print "EXCEPTION:  \n";
      for (my $i=0;$i<scalar(@fields);$i++){
         print $fields[$i].":  ".$data[$i]."\n";
      }
      print "--------------------------------------------\n";
   }
   $debug and last;
}
print "$j records processed.  $exceptcount exceptions.\n";
