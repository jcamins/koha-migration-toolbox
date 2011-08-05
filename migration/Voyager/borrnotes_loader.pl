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
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;

my $infile_name = "";
my $use_inst_id = 0;
GetOptions(
    'in=s'            => \$infile_name,
    'use_inst'        => \$use_inst_id,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $k=0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("UPDATE borrowers SET borrowernotes=? WHERE borrowernumber=?");
my $borr_sth = $dbh->prepare("SELECT borrowernumber,borrowernotes FROM borrowers WHERE cardnumber=?");

RECORD:
while (my $line = readline($in)) {
   last if ($debug and $i>10);
   chomp $line;
   $line =~ s///g;
   $line =~ s/,$//;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   my @data = split /,/ ,$line, 4;
   my $thisborrowerbar = $data[0];
   if ($use_inst_id){
      $thisborrowerbar = $data[1];
   }
   if ($thisborrowerbar eq q{}){
      $thisborrowerbar = sprintf "TEMP%d",$data[2];
   }
   my $finalnote='';
   $borr_sth->execute($thisborrowerbar);
   my $hash=$borr_sth->fetchrow_hashref();
   my $borrnumber = $hash->{'borrowernumber'};
   my $currnotes = $hash->{'borrowernotes'};
   if ($currnotes){
      $finalnote = $currnotes."\n".$data[3];
   }
   else{
      $finalnote = $data[3];
   }
   $debug and print "BORROWER:$thisborrowerbar\n$finalnote\n";
   if ($borrnumber && $doo_eet){
      $sth->execute($finalnote,$borrnumber);
      $j++;
   }
}

close $in;

print "\n\n$i lines read.\n$j notes loaded.\n";
exit;
