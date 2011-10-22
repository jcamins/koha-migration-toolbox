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

my $debug = 0;
my $infile_name = "";
my $branch = "";
my $xfile = "";

GetOptions(
    'in=s'     => \$infile_name,
    'branch=s' => \$branch,
    'excepts=s'=> \$xfile,
);

if (($infile_name eq '') || ($branch eq '') || ($xfile eq '')){
   print "You're missing something.\n";
   exit;
}

my $csv=Text::CSV->new();
my $dbh=C4::Context->dbh();
my $current_borrower_id="";
my $current_borrower_bar="";
my $i=0;
my $j=0;
my $k=0;
open INFL,"<$infile_name";
open XFL,">$xfile";
my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
my $convertq2 = $dbh->prepare("SELECT itemnumber,timestamp FROM items WHERE barcode = ?");
my $sth = $dbh->prepare("INSERT INTO issues (issuingbranch,branchcode,borrowernumber,itemnumber,date_due,issuedate) VALUES (?,?,?,?,?,?)");
while (my $row=$csv->getline(INFL)){
   my @data=@$row;
   exit if ($debug && $i>5);
   next if ($data[1] eq "Borrowers with items");
   next if ($data[0] eq "Range of Dates Considered:");
   next if ($data[1] eq "through");
   next if ($data[3] eq "Sorting By:");
   next if ($data[4] eq "Total items in group");
   next if (!$data[1]);
   if ($data[1] eq "Resp Party"){
      my $nextrow=$csv->getline(INFL);
      my @nextdata=@$nextrow;
      $current_borrower_bar = $nextdata[5];
      $convertq->execute($current_borrower_bar);
      my $arr= $convertq->fetchrow_hashref();
      $current_borrower_id = $arr->{'borrowernumber'};
      $nextrow=$csv->getline(INFL);
      $nextrow=$csv->getline(INFL);
      $nextrow=$csv->getline(INFL);
      $nextrow=$csv->getline(INFL);
      $i++;
      next;
   }
   # 
   # all we *should* have left at this point is a record of an issue.  Let's parse that.
   #
   my $itmbar=$data[1];
   $convertq2->execute($data[1]);
   $debug && print "Item Bar: $data[1] ";
   my $itemrec = $convertq2->fetchrow_hashref();
   my $itemnum = $itemrec->{'itemnumber'};
   $data[4] =~ /(\d*)\/(\d*)\/(\d*)/;
   my ($mon,$day,$year) = (($1),($2),($3));
   $year += 2000 if ($year < 11);
   $year += 1900 if ($year < 100);
   my $datedue = sprintf "%04d-%02d-%02d",$year,$mon,$day;
   $data[5] =~ /(\d*)\/(\d*)\/(\d*)/;
   ($mon,$day,$year) = (($1),($2),($3));
   $year += 2000 if ($year < 11);
   $year += 1900 if ($year < 100);
   my $dateout = sprintf "%04d-%02d-%02d",$year,$mon,$day;
   if ($itemnum){
      $debug && print "Borrower: $current_borrower_bar  ID: $current_borrower_id  Itemnum: $itemnum  Due: $datedue  Out: $dateout\n";    
      $j++;
      $sth->execute($branch,$branch,$current_borrower_id,,$itemnum,$datedue,$dateout);
   }
   else{
      $debug && print "EXCEPTION-- Borrower: $current_borrower_bar  ID: $current_borrower_id  Due: $datedue  Out: $dateout\n";    
      $k++;
      print XFL "EXCEPTION-- Branch $branch  Borrower $current_borrower_bar  Item $data[1] Due $datedue  Out $dateout\n";
   }
}
close INFL; 
close XFL;
print "$i patrons.  $j issues.  $k exceptions.\n\n";
