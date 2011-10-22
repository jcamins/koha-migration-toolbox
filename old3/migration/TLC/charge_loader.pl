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
my $borrfile = "";

GetOptions(
    'in=s'            => \$infile_name,
    'borr=s'          => \$borrfile,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '') || ($borrfile eq '')){
  print "Something's missing.\n";
  exit;
}

my $csv = Text::CSV->new();
open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $k=0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO issues (borrowernumber, itemnumber, date_due, 
                                             issuedate, branchcode, lastreneweddate,
                                             renewals) VALUES (?, ?, ?, ?, ?, ?, ?)");
my $item_sth = $dbh->prepare("SELECT itemnumber,homebranch FROM items WHERE barcode=?");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $headerline = $csv->getline($in);
my @fields = @$headerline;

RECORD:
while (my $line = $csv->getline($in)) {
   my @data = @$line;
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   my %thisissue;

   $item_sth->execute($data[0]);
   my $hash = $item_sth->fetchrow_hashref();
   $thisissue{'itemnumber'} = $hash->{'itemnumber'};
   $thisissue{'branchcode'} = $hash->{'homebranch'};
   $thisissue{'itembar'} = $data[0];
   next RECORD if (!$thisissue{'itemnumber'});

   if ($data[1] ne '            '){
      my @borr_matches =  qx{grep "^$data[1]," $borrfile};
      foreach my $match (@borr_matches){
         my $parser = Text::CSV->new();
         $parser->parse($match);
         my @row1= $parser->fields();
         $thisissue{'borrowerbar'} = $row1[1];
      }
      $borr_sth->execute($thisissue{'borrowerbar'});
      my $hash1 = $borr_sth->fetchrow_hashref();
      $thisissue{'borrowernumber'} = $hash1->{'borrowernumber'};
   } 
   
   if ($data[2] ne '            '){
      $thisissue{'duedate'} = _process_date($data[2]);
   }

   if ($data[3] ne '            '){
      $thisissue{'issuedate'} = _process_date($data[3]);
   }

   if ($data[4] ne '            '){
      $thisissue{'renewdate'} = _process_date($data[4]);
   }
     
   $thisissue{'renewals'} = $data[5];

   $debug and print Dumper(%thisissue);

   if ($thisissue{'borrowernumber'}){
      if (!thisissue{'duedate'}){
         $thisissue{'duedate'} = $thisissue{'issuedate'};
      }
      if ($doo_eet){
         $sth->execute($thisissue{'borrowernumber'},
                    $thisissue{'itemnumber'},
                    $thisissue{'duedate'},
                    $thisissue{'issuedate'},
                    $thisissue{'branchcode'},
                    $thisissue{'renewdate'},
                    $thisissue{'renewals'});
         C4::Items::ModItem({itemlost         => 0,
                             datelastborrowed => $thisissue{'issuedate'},
                             datelastseen     => $thisissue{'issuedate'},
                             onloan           => $thisissue{'duedate'}
                            },undef,$thisissue{'itemnumber'});
      }
      $j++;
   }

   if ($data[5] !~ /^CO/){
      my $lostval = $thisissue{'borrowernumber'} ? 2 : 1;
      if ($data[5] =~ /^M/){
         $lostval = 4;
      }
      if ($doo_eet){
         C4::Items::ModITem({itemlost => $lostval,},undef,thisissue{'itemnumber'});
      }
      $k++;
   }
}

close $in;

print "\n\n$i lines read.\n$j issues loaded.\n$k items marked lost or missing.\n";
exit;

sub _process_date {
   my $datein= shift;
   return undef if ($datein eq q{});
   $datein =~ m/(\d{2})-(\d{2})-(\d{4})/;
   my ($month,$day,$year) = ($1,$2,$3);
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}

