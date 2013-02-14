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
use Text::CSV_XS;
use C4::Context;
$|=1;
my $debug=0;

my $infile_name = "";
my $branchmap_filename = "";
my %branchmap;

GetOptions(
    'in=s'            => \$infile_name,
    'branch-map=s'    => \$branchmap_filename,
    'debug'           => \$debug,
);

if (($infile_name eq '')){
  print "Something's missing.\n";
  exit;
}

if ($branchmap_filename ne '') {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$branchmap_filename;
   while (my $line = $csv->getline($mapfile)) {
      my @data = @$line;
      $branchmap{$data[0]} = $data[1];
   }
   close $mapfile;
}

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $problem=0;
my %thishold = ();
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO reserves (borrowernumber, biblionumber, branchcode, reservedate, expirationdate,constrainttype ) VALUES (?, ?, ?, ?, ?, 'a')");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
my $item_sth = $dbh->prepare("SELECT biblionumber FROM items WHERE barcode=?");

while (my $line = readline($in)) {
   last if ($debug && $j>0);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   next if ($line =~ /FORM=LDHOLD/);
   if ($line =~ /DOCUMENT BOUNDARY/){
      if (%thishold){
         $debug and print Dumper(%thishold);
         if ($thishold{'borrowernumber'} && $thishold{'biblionumber'}){
            $j++;
            if (exists $branchmap{$thishold{'branchcode'}}) {
               $thishold{'branchcode'} = $branchmap{$thishold{branchcode}};
            }
            $sth->execute($thishold{'borrowernumber'},
                          $thishold{'biblionumber'},
                          $thishold{'branchcode'},
                          $thishold{'reservedate'},
                          $thishold{'expirationdate'});
         }
         else{
            print "\nProblem record:\n";
            print Dumper(%thishold);
            $problem++;
         }
      }
      %thishold=();
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
      $thishold{'borrowernumber'} = $hash->{'borrowernumber'};
      $thishold{'borrowerbar'} = $content;
      next;
   }
   if ($thistag eq "ITEM_ID"){
      $item_sth->execute($content);
      my $hash = $item_sth->fetchrow_hashref();
      $thishold{'biblionumber'} = $hash->{'biblionumber'};
      $thishold{'itembar'} = $content;
      next;
   }
   $thishold{'branchcode'} = $content if ($thistag eq "HOLD_PICKUP_LIBRARY");
   $thishold{'reservedate'} = _process_date($content) if ($thistag eq "HOLD_DATE");
   $thishold{'expirationdate'} = _process_date($content) if ($thistag eq "HOLD_EXPIRES_DATE");
}

close $in;
      if (%thishold){
         $debug and print Dumper(%thishold);
         if ($thishold{'borrowernumber'} && $thishold{'biblionumber'}){
            $j++;
            if (exists $branchmap{$thishold{'branchcode'}}) {
               $thishold{'branchcode'} = $branchmap{$thishold{branchcode}};
            }
            $sth->execute($thishold{'borrowernumber'},
                          $thishold{'biblionumber'},
                          $thishold{'branchcode'},
                          $thishold{'reservedate'},
                          $thishold{'expirationdate'});
         }
         else{
            print "\nProblem record:\n";
            print Dumper(%thishold);
            $problem++;
         }
      }


print "\n\n$i lines read.\n$j holds loaded.\n$problem problem holds not loaded.";
exit;

sub _process_date {
    my ($date_in) = @_;
    return undef if ($date_in eq "NEVER");
    my $year = substr($date_in,0,4);
    my $month = substr($date_in,4,2);
    my $day = substr($date_in,6,2);
    return sprintf "%d-%02d-%02d",$year,$month,$day;
}
