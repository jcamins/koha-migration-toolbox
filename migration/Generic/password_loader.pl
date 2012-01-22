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
    'in=s'     => \$infile_name,
    'debug' => \$debug,
    'update'=> \$doo_eet
);

if (($infile_name eq '')){
 print "You're missing something.\n";
 exit;
}

my $csv=Text::CSV->new();
my $dbh=C4::Context->dbh();
my $i=0;
my $written=0;

my $upd_sth = $dbh->prepare("update borrowers set password=? where cardnumber=?");

open my $io,"<$infile_name";

while (my $row=$csv->getline($io)){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   my @data = @$row;
   next if $data[1] eq '';
   my $password = md5_base64($data[1]);

   $debug and print "setting $data[0]...$password\n";
   $doo_eet and $upd_sth->execute($password,$data[0]);
   $written++;
}

close $io;

print "\n$i records read.\n$written records updated.\n";
