#!/usr/bin/perl
use C4::Context;
use C4::Accounts;
use strict;
use Data::Dumper;
$|=1;

my $dbh= C4::Context::dbh();

my $sth=$dbh->prepare("RENAME TABLE accountlines TO accountlines_tmp;");
$sth->execute();

$sth=$dbh->prepare(" CREATE TABLE `accountlines` (
  `borrowernumber` int(11) NOT NULL default '0',
  `accountno` smallint(6) NOT NULL default '0',
  `itemnumber` int(11) default NULL,
  `date` date default NULL,
  `amount` decimal(28,6) default NULL,
  `description` mediumtext,
  `dispute` mediumtext,
  `accounttype` varchar(5) default NULL,
  `amountoutstanding` decimal(28,6) default NULL,
  `lastincrement` decimal(28,6) default NULL,
  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `notify_id` int(11) NOT NULL default '0',
  `notify_level` int(2) NOT NULL default '0',
  KEY `acctsborridx` (`borrowernumber`),
  KEY `timeidx` (`timestamp`),
  KEY `itemnumber` (`itemnumber`),
  CONSTRAINT `accountlines_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `accountlines_ibfk_2` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`) ON DELETE SET NULL ON UPDATE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8");
$sth->execute();


$sth=$dbh->prepare("SELECT
      fee_id,payment_id,accounttype,amount,timestamp,
      fees.borrowernumber as f_borr,
      fees.itemnumber,
      fees.description as f_desc,
      payments.* from fee_transactions
      left join fees on (fee_id=fees.id) left join payments on (payment_id=payments.id)
      ORDER BY timestamp;");
$sth->execute();

my $i=0;
my %accounttypes = ("ACCTMANAGE","A",
                    "CANCELCREDIT","C",
                    "FINE","F",
                    "LOSTITEM","L",
                    "LOST_SURCHARGE","L",
                    "NEWCARD","N",
                    "RENTAL","M",
                    "SUNDRY","M");

while (my $thisrow=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $borrowernumber = $thisrow->{'f_borr'} || $thisrow->{'borrowernumber'};
   my $nextaccntno = C4::Accounts::getnextacctno($borrowernumber);
   if ($thisrow->{amount} > 0){
      _invoice_them ($borrowernumber,$thisrow->{itemnumber},$thisrow->{f_desc},$accounttypes{$thisrow->{accounttype}},
                     $thisrow->{amount},substr($thisrow->{timestamp},0,10));
   }
   elsif ($thisrow->{amount} <0){
      _pay_them ($borrowernumber,abs($thisrow->{amount}),substr($thisrow->{timestamp},0,10));
   }
}
$sth->finish();

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
    $itemnum =~ s/ //g;
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

    if ( $itemnum ne '' ) {
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
