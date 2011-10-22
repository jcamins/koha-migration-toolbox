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
use C4::Accounts;

my $debug = 0;
my $infile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
);

if ($infile_name eq ''){
   print "You're missing something.\n";
   exit;
}

my $csv=Text::CSV->new();
my $dbh=C4::Context->dbh();
my $current_borrower_id="";
my $current_borrower_bar="";
my $i=0;
my $j=0;
open INFL,"<$infile_name";
my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
my $convertq2 = $dbh->prepare("SELECT itemnumber,title FROM items left join biblio on (items.biblionumber=biblio.biblionumber) WHERE barcode = ?");
my $sth=$dbh->prepare("INSERT INTO accountlines
                       (borrowernumber,itemnumber,date,amount,description,accounttype,amountoutstanding,lastincrement,accountno)
                        VALUES (?,?,?,?,?,?,?,?,?)");
while (my $row=$csv->getline(INFL)){
   my @data=@$row;
   exit if ($debug && $i>30);
   next if ($data[1] eq "Outstanding Fines");
   next if ($data[1] =~ /^\s/);
   next if ($data[1] eq "Location:");
   next if ($data[1] eq "Borrower ID");
   next if ($data[1] eq "Comment");
   next if (!$data[1]);
   next if (!$data[5]);
   if ($data[2] eq "Home Location:"){
      my $nextrow=$csv->getline(INFL);
      $current_borrower_bar = $data[1];
      $convertq->execute($current_borrower_bar);
      my $arr= $convertq->fetchrow_hashref();
      $current_borrower_id = $arr->{'borrowernumber'};
      $i++;
      next;
   }
   # 
   # all we *should* have left at this point is a record of a fine.  Let's parse that.
   #
   my $itmbar=$data[1];
   $convertq2->execute($data[1]);
   $debug && print "Item Bar: $data[1] ";
   my $itemrec = $convertq2->fetchrow_hashref();
   my $itemnum = $itemrec->{'itemnumber'};
   $data[3] =~ /(\d*)\/(\d*)\/(\d*)/;
   my ($mon,$day,$year) = (($1),($2),($3));
   $year += 2000 if ($year < 11);
   $year += 1900 if ($year < 100);
   my $date = sprintf "%04d-%02d-%02d",$year,$mon,$day;
   my $type = $data[2];
   my $feetype = "M";
   $feetype = "F" if ($type eq "OV");
   $feetype = "L" if ($type eq "L");
   my $amount = $data[5];
   my $description = "";
   $description = "Overdue: " if ($type eq "OV");
   $description = "Lost: " if ($type eq "L");
   $description = "Collections fee: " if ($type eq "COLL");
   $description .= $type if ($description eq "");
   my $nextaccntno = C4::Accounts::getnextacctno($current_borrower_id);
   $j++;
   if ($itemnum){
      $description .= $itemrec->{'title'};
      $debug && print "Borrower: $current_borrower_bar  ID: $current_borrower_id  Itemnum: $itemnum  Date: $date Feetype: $feetype Type: $type Amt: $amount Desc: $description\n"; 
      $sth->execute($current_borrower_id,$itemnum,$date,$amount,$description,$feetype,$amount,$amount,$nextaccntno);
   }
   else{
      $description .= $data[0];
      $debug && print "EXCEPTION-- Borrower: $current_borrower_bar  ID: $current_borrower_id  Date: $date Feetype: $feetype Type: $type Amt: $amount Desc: $description\n"; 
      $sth->execute($current_borrower_id,undef,$date,$amount,$description,$feetype,$amount,$amount,$nextaccntno);
   }
}
close INFL; 
print "$i patrons.  $j fees.\n\n";
