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
#      Patron_Num, Item_Number, Request_Date, Hold_Until_Date, Pickup_Date 
#   -Item dump file from Cybertools, in CSV;  Field [0] is the item number, field [22] is the barcode!
#
# DOES:
#   -inserts current holds into database, if --update is set
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
use C4::Members;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $infile_name = "";
my $item_map_filename = q{};

GetOptions(
    'in=s'            => \$infile_name,
    'item=s'          => \$item_map_filename,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '') || ($item_map_filename eq q{})){
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
my $borr_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE sort1=?");
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $rsv_sth = $dbh->prepare("INSERT INTO reserves
                 (borrowernumber,reservedate,biblionumber,branchcode)
                  VALUES (?, ?, ?, ?)");

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
  
   my $this_reserve_date = _process_date($line->{Request_Date});

   if ($thisborrower && $thisitem && ($this_reserve_date gt "2011-01-01")) {
      $written++;
      my $item = GetItem($thisitem);
      my $borrower = GetMemberDetails($thisborrower);
      $debug and print "B:$thisborrower I:$thisitembar ($item->{biblionumber}) O:$this_reserve_date Br:$borrower->{branchcode}\n";
      if ($doo_eet){
         $rsv_sth->execute($thisborrower,
                             $this_reserve_date,
                             $item->{biblionumber},
                             $borrower->{branchcode},
                          );
      }
   }
   else{
      print "\nProblem record:\n";
      print "B:$line->{Patron_Num} ($thisborrower) I:$thisitembar--$line->{Item_Number} ($thisitem) O:$this_reserve_date\n";
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
   my ($day,$month,$year) = split /\//, $datein;
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
