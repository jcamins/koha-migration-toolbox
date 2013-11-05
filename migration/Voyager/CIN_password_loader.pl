#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -Joy Nelson --added exclusion clause 3/21/2012
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
my $exclude = '';
my $infile_name = "";

GetOptions(
    'in=s'      => \$infile_name,
    'debug'     => \$debug,
    'update'    => \$doo_eet,
    'exclude=s' => \$exclude,
);

if (($infile_name eq '')){
 print "You're missing something.\n";
 exit;
}

my $csv=Text::CSV->new({binary => 1});
my $dbh=C4::Context->dbh();
my $i=0;
my $written=0;

my $upd_sth = $dbh->prepare("update borrowers set password=? where cardnumber=? and categorycode<>?");

open my $io,"<$infile_name";

while (my $row=$csv->getline($io)){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   my @data = @$row;
   next if $data[1] eq '';
   my @password = split(/ /, $data[1]);
   my $finalpassword = md5_base64($password[0]);

#   $debug and print "setting $data[0]...$finalpassword\n";
   $doo_eet and $upd_sth->execute($finalpassword,$data[0],$exclude);
   $written++;
}

close $io;

print "\n$i records read.\n$written records updated.\n";
