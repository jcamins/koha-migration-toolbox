#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# 
# Modification log: (initial and date)
#
#---------------------------------
#
# EXPECTS:
#   -delimited file of order records
#
# DOES:
#   -creates baskets (and, if necessary, funds) and invoices.
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -counts of records created

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use C4::Context;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = $NULL_STRING;
my $biblio_map_filename = $NULL_STRING;
my %biblio_map;
my $fund_map_filename = $NULL_STRING;
my %fund_map;
my $create_funds = 0;
my $default_owner = 0;
my $default_branch = $NULL_STRING;
my $default_date = $NULL_STRING;
my $fundname_suffix = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'bib_map=s' => \$biblio_map_filename,
    'fund_map=s'   => \$fund_map_filename,
    'create_funds' => \$create_funds,
    'owner=s'   => \$default_owner,
    'branch=s'  => \$default_branch,
    'fund_suffix=s' => \$fundname_suffix,
    'basket_date=s' => \$default_date,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$biblio_map_filename,$default_branch) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if ($biblio_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$biblio_map_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $biblio_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($fund_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$fund_map_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $fund_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $dbh=C4::Context->dbh();
my $budgets_created = 0;
my $baskets_created = 0;
my $orders_created  = 0;
my ($day, $mon, $year) = (localtime)[3..5];
my $today = sprintf "%04d-%02d-%02d\n", 1900+$year, 1+$mon, $day;
if ($default_date eq $NULL_STRING) {
   $default_date=$today;
}

my $sth_find_vendor = $dbh->prepare("SELECT id FROM aqbooksellers WHERE contpos = ?");
my $sth_find_period = $dbh->prepare("SELECT budget_period_id FROM aqbudgetperiods WHERE ? 
                                     BETWEEN budget_period_startdate AND budget_period_enddate");
my $sth_find_fund   = $dbh->prepare("SELECT budget_id FROM aqbudgets WHERE budget_code = ? AND budget_period_id = ?");
my $sth_find_basket = $dbh->prepare("SELECT basketno FROM aqbasket WHERE basketname = ? AND booksellerid = ?");
my $sth_add_fund    = $dbh->prepare("INSERT INTO aqbudgets 
                                     (budget_code, budget_period_id, budget_branchcode, budget_owner_id) 
                                      VALUES (?,?,?,?)");
my $sth_add_basket = $dbh->prepare("INSERT INTO aqbasket 
                                    (basketname, note, creationdate, closedate, booksellerid, authorisedby) 
                                    VALUES (?, ?, ?, ?, ?, ?)");

my $sth_add_order = $dbh->prepare("INSERT INTO aqorders 
                                   (biblionumber, entrydate, quantity, quantityreceived, currency, listprice, 
                                    datereceived, booksellerinvoicenumber, freight, notes, purchaseordernumber, 
                                    basketno, biblioitemnumber, rrp, ecost, budget_id, 
                                    budgetgroup_id) 
                                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)");


open my $input_file,'<',$input_filename;
my $dum = readline($input_file);  #skip header row!
LINE:
while (my $line=readline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s/~//g;
   $line =~ s/\r//g;
   my ($bibrecordstr, $ordernumber, $location, $quantity, $fundname, $vendorcode,
       $po_number, $requestor, $int_note, undef, $note, $payment_string) = split (/\|/,$line,12);
   my ($bibrecordnum,undef) = split /\^/,$bibrecordstr;
   if (!$bibrecordnum) {
      print "BIBLIO NOT DEFINED: ORDER # $ordernumber\n";
      $problem++;
      next LINE;
   }
   my $biblionumber=$biblio_map{$bibrecordnum};
   if (!$biblionumber) {
      print "BIBLIO NOT FOUND: $bibrecordnum ORDER # $ordernumber\n";
      $problem++;
      next LINE;
   }
   $location = uc($location);
   $location =~ s/\s+$//;
   $vendorcode =~ s/\s+$//;
   $sth_find_vendor->execute($vendorcode);
   my $vendor = $sth_find_vendor->fetchrow_hashref();
   if (!$vendor->{id}) {
      print "VENDOR NOT FOUND: $vendorcode\n";
      $problem++;
      next LINE;
   }
   $fundname =~ s/\s+$//g;
   if (exists ($fund_map{$fundname})) {
      $fundname = $fund_map{$fundname};
   }
   $fundname .= $fundname_suffix;

   my @payments = split (/\^/, $payment_string);
   my $full_notes = $int_note.' -- '.$note;
   $full_notes =~ s/\^/ -- /g;
   $full_notes =~ s/^ \-\- //;
   $full_notes =~ s/ \-\- $//;
   my $basket_id = 0;
   if (scalar(@payments) > 0) {
PAYMENT:
      foreach my $payment (@payments){
         my ($paiddate,$invoicedate,$invoicenum,$amountpaid,$vouchernum,
             $copies,$sub_from,$sub_to,$note) = split (/\|/,$payment);
         my $paid_date_iso    = process_date($paiddate);
         my $invoice_date_iso = process_date($invoicedate);
         $sth_find_period->execute($paid_date_iso);
         my $period = $sth_find_period->fetchrow_hashref();
         if (!$period->{budget_period_id}) {
            print "BUDGET PERIOD NOT FOUND: $paid_date_iso\n";
            $problem++;
            next PAYMENT;
         }
         $sth_find_fund->execute($fundname, $period->{budget_period_id});
         my $fund = $sth_find_fund->fetchrow_hashref();
         my $budget_id = $fund->{budget_id} || $NULL_STRING;
         if ($budget_id eq $NULL_STRING) {
            if (!$create_funds) {
               print "FUND NOT FOUND: $fundname\n";
               $problem++;
               next PAYMENT;
            }
       
            $debug and print "Adding fund $fundname/$period->{budget_period_id}\n";
            if ($doo_eet) {
               $sth_add_fund->execute($fundname,$period->{budget_period_id},$default_branch,$default_owner);
               $budget_id = $dbh->last_insert_id(undef,undef,undef,undef);
            }
            $budgets_created++;
         }
         my $currency         = 'USD';
         my $budget_group_id  = 0;
         my $freight          = 0;
         if ($copies eq $NULL_STRING) {
            $copies = 0;
         }
         $copies              = int($copies);

         $sth_find_basket->execute($invoicenum,$vendor->{id});
         my $basket = $sth_find_basket->fetchrow_hashref();
         my $basket_id = $basket->{basketno} || $NULL_STRING;
         if ($basket_id eq $NULL_STRING) {
            $debug and print "Adding basket $invoicenum/$vendor->{id}\n";
            if ($doo_eet) {
               $sth_add_basket->execute($invoicenum, $full_notes,  $invoice_date_iso, $invoice_date_iso, $vendor->{id}, $default_owner);
               $basket_id = $dbh->last_insert_id(undef,undef,undef,undef);
            }
            $baskets_created++;
         }
         $debug and print "Adding order on biblio $biblionumber\n";
         if ($doo_eet) {
            $sth_add_order->execute( $biblionumber,  $invoice_date_iso, $copies,     $copies,     $currency,   $amountpaid,
                                     $paid_date_iso, $invoicenum,       $freight,    $note,       $vouchernum, 
                                     $basket_id,     $biblionumber,     $amountpaid, $amountpaid, $budget_id,
                                     $budget_group_id );
         }
         $orders_created++;
         next PAYMENT;
      }
   }
   else {
      $sth_find_period->execute($default_date);
      my $period = $sth_find_period->fetchrow_hashref();
      if (!$period->{budget_period_id}) {
         print "BUDGET PERIOD NOT FOUND: $default_date\n";
         $problem++;
         next PAYMENT;
      }
      $sth_find_fund->execute($fundname, $period->{budget_period_id});
      my $fund = $sth_find_fund->fetchrow_hashref();
      my $budget_id = $fund->{budget_id} || $NULL_STRING;
      if ($budget_id eq $NULL_STRING) {
         if (!$create_funds) {
            print "FUND NOT FOUND: $fundname\n";
            $problem++;
            next PAYMENT;
         }
         
         $debug and print "Creating budget $fundname/$period->{budget_period_id}\n";
         if ($doo_eet) {
            $sth_add_fund->execute($fundname,$period->{budget_period_id},$default_branch,$default_owner);
            $budget_id = $dbh->last_insert_id(undef,undef,undef,undef);
         }
         $budgets_created++;
      }

      $sth_find_basket->execute("Dummy Basket",$vendor->{id});
      my $basket = $sth_find_basket->fetchrow_hashref(); 
      my $basket_id = $basket->{basketno} || $NULL_STRING;
      if ($basket_id eq $NULL_STRING) {
         $debug and print "Creating basket Dummy Basket/$vendor->{id}\n";
         if ($doo_eet) {
            $sth_add_basket->execute("Dummy Basket", $full_notes,  $default_date, undef, $vendor->{id}, $default_owner);
            $basket_id = $dbh->last_insert_id(undef,undef,undef,undef);
         }
         $baskets_created++;
      }
      $debug and print "Creating order on biblio $biblionumber\n";
      if ($doo_eet) {
         $sth_add_order->execute( $biblionumber, $default_date, $quantity, 0 , 'USD', 0,
                                  '',            '',     0,         'Migrated from Millenium as unreceived', '',
                                  $basket_id,    $biblionumber, 0, 0, $budget_id,
                                  0 );
      }
      $orders_created++;
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$budgets_created budgets were added.
$baskets_created baskets were added.
$orders_created orders were created.
$problem records not loaded due to problem.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;

sub process_date {
  my $the_date = shift;
  $the_date =~ s/^(\d\d)\-(\d\d)\-(\d\d)/$3\-$1\-$2/; #Rearrange parts
  if (int(substr($the_date,0,2)) < 15) {
     $the_date = '20'.$the_date;
  } else {
     $the_date = '19'.$the_date;
  }
  return $the_date;
}
