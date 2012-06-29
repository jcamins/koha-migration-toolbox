#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# - DRB updated to current standards
#
#---------------------------------
#
# EXPECTS:
#   -CSV of accounts data from Voyager extract
#
# DOES:
#   -loads account records, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be added, if --debug is set
#   -count of records read 
#   -count of records added
#   -sum of bills

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
use C4::Accounts;
use C4::Items;

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
my $map_filename   = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'map=s'    => \$map_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %accounttype_map;
my %description_map;
if ($map_filename ne $NULL_STRING) {
   my $csv=Text::CSV_XS->new();
   open my $mapfile,'<',$map_filename;
   while (my $line = $csv->getline($mapfile)) {
      my @data=@$line;
      $accounttype_map{$data[0]} = $data[1];
      $description_map{$data[0]} = $data[2];
   }
   close $mapfile;
}

my $total_bills = 0;
my $csv = Text::CSV_XS->new({ binary => 1 });
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO accountlines 
                         (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding, itemnumber)
                          VALUES (?, ?, ?, ?,?, ?,?,?)");
my $borrower_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");
open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file));
RECORD:
while (my $line = $csv->getline_hr($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   $borrower_sth->execute($line->{PATRON_BARCODE});
   my $borrower = $borrower_sth->fetchrow_hashref;
   if (!$borrower->{borrowernumber}) {
      $problem++;
      next RECORD;
   }

   my $itemnumber = undef;
   if ($line->{ITEM_BARCODE} ne $NULL_STRING) {
      $itemnumber = GetItemnumberFromBarcode($line->{ITEM_BARCODE});
   }

   my $transdate = _process_date($line->{CREATE_DATE});
   my $accountno  = getnextacctno($borrower->{borrowernumber});
   my $amount = $line->{FINE_FEE_BALANCE}/100;

   my $description = $description_map{$line->{FINE_FEE_TYPE}} || $NULL_STRING;
   $description .= ' - '.$line->{FINE_FEE_NOTE};
   $description =~ s/^ \- //;
   $description =~ s/ \- $//;
   my $accounttype = $accounttype_map{$line->{FINE_FEE_TYPE}} || 'M';

   $debug and print "Borrower $line->{PATRON_BARCODE} ($borrower->{borrowernumber}) Amount $amount Date $transdate -- $description ($itemnumber)\n";

   if ($doo_eet) {
      $sth->execute($borrower->{borrowernumber},$accountno,$transdate,$amount,$description,$accounttype,$amount,$itemnumber);
   }
   $written++;
   $total_bills += $amount;
}
 
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
Total bill value: $total_bills 
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;

sub _process_date {
   my $datein=shift;
   return undef if $datein eq $NULL_STRING;
   my ($month,$day,$year) = split /\//,$datein;
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
