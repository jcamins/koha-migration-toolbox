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
use Digest::MD5 qw(md5_base64);
$|=1;
my $debug=0;
my $doo_eet=0;

my $infile_name = "";

GetOptions(
   'debug' => \$debug,
   'update'=> \$doo_eet
);

#if (($infile_name eq '')){
# print "You're missing something.\n";
# exit;
#}

my $dbh=C4::Context->dbh();
my $i=0;

my $sth = $dbh->prepare("select borrowernumber,surname,firstname from borrowers where categorycode ='STAFF'");
my $upd_sth = $dbh->prepare("update borrowers set userid=?,password=? where borrowernumber=?");
$sth->execute();
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $userid=lc ( substr($row->{'firstname'},0,1).$row->{'surname'});
   my $password = md5_base64("password".length($row->{'surname'}));
   $debug and print "setting $userid...$password\n";
   $doo_eet and $upd_sth->execute($userid,$password,$row->{'borrowernumber'});
}

print "\n$i records added.\n";
