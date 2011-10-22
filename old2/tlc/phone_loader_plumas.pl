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
use Getopt::Long;
use C4::Context;
use C4::Members;

my $debug=0;
my $infile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
);

if (($infile_name eq '')){
    print "You're missing something.\n";
    exit;
}

my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("select borrowernumber from borrowers where sort1 =?");
my $i=0;
open INFL,"<$infile_name";
while (my $line1=readline(INFL)){
   my $line2=readline(INFL);
   my $line3=readline(INFL);
   my $line4=readline(INFL);
   chomp $line1;
   chomp $line2;
   chomp $line3;
   chomp $line4;
   $line1 =~ s/^\"//g;
   $line2 =~ s/^\"//g;
   $line3 =~ s/^\"//g;
   $line4 =~ s/^\"//g;
   $line1 =~ s/\"$//g;
   $line2 =~ s/\"$//g;
   $line3 =~ s/\"$//g;
   $line4 =~ s/\"$//g;

   $i++;
   print "." if (!$debug);
   print "\r$i" unless ($i % 100);
   exit if ($debug && $i>20);
   my $agency = substr($line1,0,12);
   $agency =~ s/ //g;
   my $addrnum = substr($line1,25,1);
   my $addr = substr($line1,27,79);
   $addr =~ s/\s+$//g;
   my $city = substr($line2,0,30);
   $city =~ s/\s+$//g;
   my $state = substr($line2,31,5);
   $state =~ s/ //g;
   $city .= ", ".$state;
   my $zip = substr($line2,62,20);
   $zip =~ s/\s+//g;
   my $phone = substr($line3,0,16);
   $phone =~ s/ //g;
   my $phone2 = substr($line3,17,16);
   $phone2 =~ s/ //g;
   $debug && print "$agency^$addrnum^$addr^$city^$zip^$phone^$phone2^\n";
   $sth->execute($agency);
   my $rec=$sth->fetchrow_hashref();
   if (!$debug){
      if ($addrnum == 2){
         C4::Members::ModMember( borrowernumber => $rec->{'borrowernumber'},
                                 B_address      => $addr,
                                 B_city         => $city,
                                 B_zipcode      => $zip,
                                 B_phone        => $phone,
                                 phonepro       => $phone2);
      }
      else{
         C4::Members::ModMember( borrowernumber => $rec->{'borrowernumber'},
                                 address      => $addr,
                                 city         => $city,
                                 zipcode      => $zip,
                                 phone        => $phone,
                                 phonepro       => $phone2);
      }
   }
}
close INFL; 

