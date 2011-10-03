#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -input CSV with these columns, in ANY order:
#      Patron_Num, Item_Number, Date_Out, Date_Due, Number_Renewals
#      Time_Due,   Time_Out
#   -Item dump file from Cybertools, in CSV;  Field [0] is the item number, field [22] is the barcode!
#   -Lost value to set
#
# DOES:
#   -inserts current checkouts into database, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would have been done, if --debug is set
#   -problematic records
#   -count of records read
#   -count of records inserted
#   -count of failed insertions

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $infile_name       = q{};
my $item_map_filename = q{};
my $lost_value        = 0;

GetOptions(
    'in=s'            => \$infile_name,
    'items=s'         => \$item_map_filename,
    'lost=i'          => \$lost_value,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '') || ($item_map_filename eq q{}) || ($lost_value == 0)){
  print "Something's missing.\n";
  exit;
}

print "Loading item barcode map:\n";
my $mapcsv = Text::CSV_XS->new();
my %item_map;
open my $itemmap,"<",$item_map_filename;
while (my $map_line = $mapcsv->getline($itemmap)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$map_line;
   $item_map{$data[0]} = $data[22];
}
print "\n$i lines read.\n\n";

print "Processing issues.\n";
$i=0;
my $csv = Text::CSV_XS->new();
open my $in,"<$infile_name";
$csv->column_names( $csv->getline($in) );
my $written=0;
my $problem=0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO issues (borrowernumber, itemnumber, date_due, issuedate, branchcode, renewals) VALUES (?, ?, ?, ?, ?, ?)");
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE sort1=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
RECORD:
while (my $line = $csv->getline_hr($in)) {
   $i++;
   print ".";
   print "\r$i" unless $i % 100;

   $borr_sth->execute($line->{Patron_Num});
   my $hash=$borr_sth->fetchrow_hashref();
   my $thisborrower=$hash->{'borrowernumber'};

   my $thisitembar = $item_map{ $line->{Item_Number} } || "";
   my $thisitem;
   if ($thisitembar ne q{}) {
      $item_sth->execute($thisitembar);
      $hash=$item_sth->fetchrow_hashref();
      $thisitem = $hash->{'itemnumber'};
   }
  
   my $thisdateout = _process_date($line->{Date_Out});
   my $thisdatedue = _process_date($line->{Date_Due});
   my $renewals = 0;
   if ($line->{Number_Renewals} ne q{}) {
      $renewals = $line->{Number_Renewals};
   }

   if ($thisborrower && $thisitem){
      $written++;
      my $item = GetItem($thisitem);
      $debug and print "B:$thisborrower I:$thisitembar O:$thisdateout D:$thisdatedue R:$renewals Br:$item->{homebranch}\n";
      if ($doo_eet){
         $sth->execute($thisborrower,
                       $thisitem,
                       $thisdatedue,
                       $thisdateout,
                       $item->{homebranch},
                       $renewals);
         C4::Items::ModItem({itemlost         => $lost_value,
                             datelastborrowed => $thisdateout,
                             datelastseen     => $thisdateout,
                             onloan           => $thisdatedue,
                            },undef,$thisitem);
      }
   }
   else{
      print "\nProblem record:\n";
      print "B:$thisborrower ($thisborrower) I:$thisitembar--$line->{Item_Number} ($thisitem) O:$thisdateout D:$thisdatedue\n";
      $problem++;
   }
   last if ($debug && $written>20);
   next;
}

close $in;

print "\n\n$i lines read.\n$written issues loaded.\n$problem problem issues not loaded.\n";
exit;

sub _process_date {
   my $datein=shift;
   return undef if $datein eq q{};
   my ($month,$day,$year) = split /\//, $datein;
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
