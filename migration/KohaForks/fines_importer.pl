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
#   -nothing
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -nothing

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use C4::Accounts;
use C4::Context;
use C4::Members;
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
my $type_map_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'map=s'    => \$type_map_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$type_map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %accounttypes;
if ($type_map_filename ne q{}) {
   print "Reading map file...\n";
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$type_map_filename;
   while (my $line = $csv->getline($map_file)) {
      my @data = @$line;
      $accounttypes{$data[0]} = $data[1];
   }
   close $map_file;
}

my $csv=Text::CSV_XS->new( { binary => 1 });
open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file));
LINE:
while (my $thisrow=$csv->getline_hr($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $borrower_barcode = $thisrow->{'f_borr'};
   my $borrower = GetMember( 'cardnumber' => $borrower_barcode );
   my $itemnumber = GetItemnumberFromBarcode($thisrow->{'barcode'});
   my $nextaccntno = C4::Accounts::getnextacctno($borrower->{borrowernumber});
   if ($thisrow->{amount} > 0){
      _invoice_them ($borrower->{borrowernumber},$itemnumber,$thisrow->{f_desc},$accounttypes{$thisrow->{accounttype}},
                     $thisrow->{amount},substr($thisrow->{timestamp},0,10));
   }
   elsif ($thisrow->{amount} <0){
      _pay_them ($borrower->{borrowernumber},abs($thisrow->{amount}),substr($thisrow->{timestamp},0,10));
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;

sub _pay_them {
    my ( $borrowernumber, $data ,$date ) = @_;
    my $dbh        = C4::Context->dbh;
    my $newamtos   = 0;
    my $accdata    = "";
    my $amountleft = $data;

    # begin transaction
    my $nextaccntno = getnextacctno($borrowernumber);

    # get lines with outstanding amounts to offset
    my $sth3 = $dbh->prepare(
        "SELECT * FROM accountlines
  WHERE (borrowernumber = ?) AND (amountoutstanding<>0)
  ORDER BY date"
    );
    $sth3->execute($borrowernumber);

# offset transactions
    while ( ( $accdata = $sth3->fetchrow_hashref ) and ( $amountleft > 0 ) ) {
        if ( $accdata->{'amountoutstanding'} < $amountleft ) {
            $newamtos = 0;
            $amountleft -= $accdata->{'amountoutstanding'};
        }
        else {
            $newamtos   = $accdata->{'amountoutstanding'} - $amountleft;
            $amountleft = 0;
        }
        my $thisacct = $accdata->{accountno};
        my $usth     = $dbh->prepare(
            "UPDATE accountlines SET amountoutstanding= ?
     WHERE (borrowernumber = ?) AND (accountno=?)"
        );
        $usth->execute( $newamtos, $borrowernumber, $thisacct );
        $usth->finish;
    }
    # create new line
    my $usth = $dbh->prepare(
        "INSERT INTO accountlines
  (borrowernumber, accountno,date,amount,description,accounttype,amountoutstanding)
  VALUES (?,?,?,?,'Payment,thanks','Pay',?)"
    );
    $usth->execute( $borrowernumber, $nextaccntno, $date, 0 - $data, 0 - $amountleft );
    $usth->finish;
    $sth3->finish;
}

sub _invoice_them {
    my ( $borrowernumber, $itemnum, $desc, $type, $amount, $date ) = @_;
    my $dbh      = C4::Context->dbh;
    my $notifyid = 0;
    my $insert;
    if ($itemnum) {
       $itemnum =~ s/ //g;
    }
    my $accountno  = getnextacctno($borrowernumber);
    my $amountleft = $amount;
    if (   ( $type eq 'L' )
        or ( $type eq 'F' )
        or ( $type eq 'A' )
        or ( $type eq 'N' )
        or ( $type eq 'M' ) )
    {
        $notifyid = 1;
    }

    if ( $itemnum  ) {
        my $sth = $dbh->prepare(
            "INSERT INTO  accountlines
                        (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding, itemnumber,notify_id)
        VALUES (?, ?, ?, ?,?, ?,?,?,?)");
     $sth->execute($borrowernumber, $accountno, $date, $amount, $desc, $type, $amountleft, $itemnum,$notifyid) || return $sth->errstr;
  } else {
    my $sth=$dbh->prepare("INSERT INTO  accountlines
            (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding,notify_id)
            VALUES (?, ?, ?, ?, ?, ?, ?,?)"
        );
        $sth->execute( $borrowernumber, $accountno, $date, $amount, $desc, $type,
            $amountleft, $notifyid );
    }
    return 0;
}

