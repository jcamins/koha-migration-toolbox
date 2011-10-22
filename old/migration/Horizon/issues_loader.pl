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

my $infile_name = "";
my $branch = "";

GetOptions(
    'in=s'            => \$infile_name,
    'branch=s'        => \$branch,
    'debug'           => \$debug,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $csv = Text::CSV->new();
open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $problem=0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO issues (borrowernumber, itemnumber, date_due, issuedate, branchcode) VALUES (?, ?, ?, ?, ?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $headerline = $csv->getline($in);
my @fields = @$headerline;

while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $debug and print Dumper(@data);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   my %thisissue;
   $thisissue{'branchcode'} = $branch if ($branch);
   for (my $k=0;$k<scalar(@data);$k++){
      if ($fields[$k] eq "Cardnumber"){
         $borr_sth->execute($data[$k]);
         my $hash = $borr_sth->fetchrow_hashref();
         $thisissue{'borrowernumber'} = $hash->{'borrowernumber'};
         $thisissue{'borrowerbar'} = $data[$k];
         next;
      }
      if ($fields[$k] eq "Barcode"){
         $item_sth->execute($data[$k]);
         my $hash = $item_sth->fetchrow_hashref();
         $thisissue{'itemnumber'} = $hash->{'itemnumber'};
         $thisissue{'itembar'} = $data[$k];
         next;
      }
      if ($fields[$k] eq "Date_Out"){
         $thisissue{'issuedate'} = $data[$k];
      }
      if ($fields[$k] eq "Date_Due"){
         $thisissue{'duedate'} = $data[$k];
      }
   }
      
   if (%thisissue){
      $debug and print Dumper(%thisissue);
      if ($thisissue{'borrowernumber'} && $thisissue{'itemnumber'}){
         $j++;
         $sth->execute($thisissue{'borrowernumber'},
                       $thisissue{'itemnumber'},
                       $thisissue{'duedate'},
                       $thisissue{'issuedate'},
                       $thisissue{'branchcode'});
         C4::Items::ModItem({itemlost         => 0,
                             datelastborrowed => $thisissue{'issuedate'},
                             datelastseen     => $thisissue{'issuedate'},
                             onloan           => $thisissue{'duedate'}
                            },undef,$thisissue{'itemnumber'});
      }
      else{
         print "\nProblem record:\n";
         print Dumper(%thisissue);
         $problem++;
      }
   }
   %thisissue=();
   last if ($debug && $i>0);
   next;
}

close $in;

print "\n\n$i lines read.\n$j issues loaded.\n$problem problem issues not loaded.";
exit;

