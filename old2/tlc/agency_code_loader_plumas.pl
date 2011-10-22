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
my $i=0;
open INFL,"<$infile_name";
my $sth = $dbh->prepare("UPDATE borrowers SET sort1 = ? WHERE cardnumber = ?");
while (my $row=readline(INFL)){
   next if ($row =~ /[a-zA-Z\-]/);
   next if ($row =~ /^\s*$/);
   next if ($row =~ /^$/);
   $debug and print "row: $row\n";
   $row =~ /\s*(\d*)\s*(\d*)/;
   my ($agency,$bar) = (($1),($2));
   $debug and print "$bar: $agency\n";
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   exit if ($debug && $i>20);
   $sth->execute($agency,$bar) if (!$debug);
}
close INFL; 

