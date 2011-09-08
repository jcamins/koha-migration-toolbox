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
use Data::Dumper;
use Getopt::Long;
use C4::Context;
$|=1;
my $debug=0;

my $infile_name = "";

GetOptions(
    'in=s'            => \$infile_name,
    'debug'           => \$debug,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $problem=0;
my %thisissue = ();
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO issues (borrowernumber, itemnumber, date_due, issuedate, branchcode) VALUES (?, ?, ?, ?, ?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");

while (my $line = readline($in)) {
   last if ($debug && $j>0);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   next if ($line =~ /FORM=LDCHARGE/);
   if ($line =~ /DOCUMENT BOUNDARY/){
      if (%thisissue){
         $debug and print Dumper(%thisissue);
         if ($thisissue{'borrowernumber'} && $thisissue{'itemnumber'}){
            $j++;
            $sth->execute($thisissue{'borrowernumber'},
                          $thisissue{'itemnumber'},
                          $thisissue{'duedate'},
                          $thisissue{'issuedate'},
                          $thisissue{'branchcode'});
         }
         else{
            print "\nProblem record:\n";
            print Dumper(%thisissue);
            $problem++;
         }
      }
      %thisissue=();
      next;
   }
   $debug and print $line."\n";
   $line =~ /^\.([\w\/]+)\./;
   my $thistag = $1;
   $line =~ /\|a(.*)$/;
   my $content = $1;
   $debug and print "$thistag ~~ $content ~~\n";
   
   if ($thistag eq "USER_ID"){
      $borr_sth->execute($content);
      my $hash = $borr_sth->fetchrow_hashref();
      $thisissue{'borrowernumber'} = $hash->{'borrowernumber'};
      $thisissue{'borrowerbar'} = $content;
      next;
   }
   if ($thistag eq "ITEM_ID"){
      $item_sth->execute($content);
      my $hash = $item_sth->fetchrow_hashref();
      $thisissue{'itemnumber'} = $hash->{'itemnumber'};
      $thisissue{'itembar'} = $content;
      next;
   }
   $thisissue{'branchcode'} = $content if ($thistag eq "CHRG_LIBRARY");
   $thisissue{'issuedate'} = _process_date($content) if ($thistag eq "CHRG_DC");
   $thisissue{'duedate'} = _process_date($content) if ($thistag eq "CHRG_DATEDUE");
}

close $in;
#handle the last one!
if (%thisissue){
   $debug and print Dumper(%thisissue);
   if ($thisissue{'borrowernumber'} && $thisissue{'itemnumber'}){
      $j++;
      $sth->execute($thisissue{'borrowernumber'},
                    $thisissue{'itemnumber'},
                    $thisissue{'duedate'},
                    $thisissue{'issuedate'},
                    $thisissue{'branchcode'});
   }
   else{
      print "\nProblem record:\n";
      print Dumper(%thisissue);
      $problem++;
   }
}

print "\n\n$i lines read.\n$j issues loaded.\n$problem problem issues not loaded.";
exit;

sub _process_date {
    my ($date_in) = @_;
    return "2050-12-31" if ($date_in eq "NEVER");
    my $year = substr($date_in,0,4);
    my $month = substr($date_in,4,2);
    my $day = substr($date_in,6,2);
    return sprintf "%d-%02d-%02d",$year,$month,$day;
}
