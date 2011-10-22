#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use warnings;
use Getopt::Long;
use Text::CSV;
use C4::Context;
$|=1;
$debug=0;
$doo_eet=0;

GetOptions(
    'update'     => \$doo_eet,
    'debug'      => \$debug,
);

#if (($infile_name eq '')){
#   print "You're missing something.\n";
#   exit;
#}

my $dbh=C4::Context->dbh();
my $i=0;
my $find = $dbh->prepare("SELECT borrowernumber,cardnumber,userid FROM borrowers");
my $sth = $dbh->prepare("UPDATE borrowers SET cardnumber=? WHERE borrowernumber=?");
$find->execute();
while (my $row=$find->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($row->{'cardnumber'} ne $row->{'userid'}){
      print "Changing $row->{'cardnumber'} to $row->{'userid'}\n" if ($debug);
      if ($doo_eet){
         $sth->execute($row->{'userid'},$row->{'borrowernumber'});
      }
   }
}

print "\n$i records updated.\n";
