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
#      TRANS_DATE, TRANS_TYPE_ID, Item_Number, Patron_Num, Trans_Date_Due
#   -Item dump file from Cybertools, in CSV;  Field [0] is the item number, field [22] is the barcode!
#   -Transaction codes for charge, discharge, and renewal
#
# DOES:
#   -inserts old checkouts into database, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would have been done, if --debug is set
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

my $input_filename    = q{};
my $item_map_filename = q{};
my $issue_code        = 0;
my $renew_code        = 0;
my $return_code       = 0;

GetOptions(
    'in=s'            => \$input_filename,
    'item=s'          => \$item_map_filename,
    'issue=i'         => \$issue_code,
    'renew=i'         => \$renew_code,
    'return=i'        => \$return_code,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if ( ($input_filename eq q{}) 
     || ($item_map_filename eq q{})
     || !$issue_code
     || !$renew_code
     || !$return_code
   ){
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
open my $in,'<',$input_filename;
$csv->column_names( $csv->getline($in) );
my $written = 0;
my $problem = 0;
my $dbh = C4::Context->dbh();
my $borr_sth   = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE sort1=?");
my $item_sth   = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $issue_sth  = $dbh->prepare("INSERT INTO old_issues (borrowernumber,itemnumber,date_due,branchcode,issuedate,renewals) 
                                VALUES (?,?,?,?,?,0)");
my $renew_sth  = $dbh->prepare("UPDATE old_issues SET renewals=renewals+1, lastreneweddate=? 
                                WHERE borrowernumber=? AND itemnumber=? AND returndate IS NULL");
my $return_sth = $dbh->prepare("UPDATE old_issues SET returndate=? 
                                WHERE borrowernumber=? AND itemnumber=? AND returndate IS NULL");
my $renew2_sth  = $dbh->prepare("UPDATE old_issues SET renewals=renewals+1, lastreneweddate=? 
                                WHERE borrowernumber IS NULL AND itemnumber=? AND returndate IS NULL");
my $return2_sth = $dbh->prepare("UPDATE old_issues SET returndate=? 
                                WHERE borrowernumber IS NULL AND itemnumber=? AND returndate IS NULL");
RECORD:
while (my $line = $csv->getline_hr($in)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   $line->{Patron_Num} =~ s/\.00//;
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
  
   my $thisdate    = _process_date($line->{TRANS_DATE});
   my $thisdatedue = _process_date($line->{Trans_Date_Due});
   
   $debug and last RECORD if ($thisdate ge '1989-01-01');

   if ($thisitem){
   $debug and next RECORD if ($line->{Item_Number} ne '210403');
      $written++;
      $line->{TRANS_TYPE_ID} =~ s/\.00//;
      if ($line->{TRANS_TYPE_ID} eq $issue_code) {
         my $item = GetItem($thisitem);
         $debug and print "ISSUE B:$thisborrower I:$thisitembar ($thisitem) O:$thisdate D:$thisdatedue Br:$item->{homebranch}\n";
         if ($doo_eet) {
            $issue_sth->execute($thisborrower,
                                $thisitem,
                                $thisdatedue,
                                $item->{homebranch},
                                $thisdate,
                               );
         }
      }
      elsif ($line->{TRANS_TYPE_ID} eq $renew_code) {
         $debug and print "RENEW B:$thisborrower I:$thisitembar ($thisitem) O:$thisdate\n";
         if ($doo_eet) {
            if ($thisborrower){
               $renew_sth->execute($thisdate,
                                   $thisborrower,
                                   $thisitem,
                                  );
            }
            else{
               $renew2_sth->execute($thisdate,
                                   $thisitem,
                                  );
            }
         }
      }
      elsif ($line->{TRANS_TYPE_ID} eq $return_code) {
         $debug and print "RETURN B:$thisborrower I:$thisitembar ($thisitem) O:$thisdate\n";
         if ($doo_eet) {
            if ($thisborrower) {
               $return_sth->execute($thisdate,
                                    $thisborrower,
                                    $thisitem,
                                   );
            }
            else{
               $return2_sth->execute($thisdate,
                                    $thisitem,
                                   );
            }
         }
      }
      else {
         $written--;  #junk records with none of the above codes; shouldn't happen.
      }
   }
   else{
      #$debug and print "Problem:\n";
      #$debug and print "B:$line->{Patron_Num} ($thisborrower) I:$thisitembar ($thisitem) O:$thisdate D:$thisdatedue T:$line->{TRANS_TYPE_ID}\n";
      $problem++;
   }
   last if ($debug && $written>20);
   next;
}

close $in;

print "\n\n$i lines read.\n$written issues loaded.\n$problem problem issues not loaded.\n";
exit;

sub _process_date {
   my $input_date=shift;
   if ($input_date eq q{}) {
      return;
   }
   my ($datein,undef)     = split / /,  $input_date;
   my ($month,$day,$year) = split /\//, $datein;
   return sprintf '%4d-%02d-%02d',$year,$month,$day;
}
