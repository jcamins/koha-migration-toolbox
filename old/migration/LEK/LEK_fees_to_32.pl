#!/usr/bin/perl
use C4::Context;
use C4::Accounts;
use strict;
use Data::Dumper;

my $dbh= C4::Context::dbh();

my $sth=$dbh->prepare("DROP TABLE IF EXISTS accountlines;");
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
my $counter=0;
while (my $thisrow=$sth->fetchrow_hashref()){
   $counter++;
   if ($counter%1000==0) {
      print "$counter records processed...\n";
   }
   if ($thisrow->{'accounttype'} eq "FINE"){
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      my $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,itemnumber,date,amount,description,accounttype,amountoutstanding,lastincrement,accountno)
             VALUES (?,?,?,?,?,'F',?,?,?)");
      $sth2->execute($thisrow->{'f_borr'},$thisrow->{'itemnumber'} , $thisrow->{'timestamp'}, $thisrow->{'amount'},
                    $thisrow->{'f_desc'}, $thisrow->{'amount'} , $thisrow->{'amount'} , $nextaccntno);
      $sth2->finish();
   }
   elsif ($thisrow->{'accounttype'} eq "PAYMENT"){
      my $sth2=$dbh->prepare("SELECT accountno,amountoutstanding FROM accountlines
            WHERE borrowernumber = ? AND description = ?");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'f_desc'});
      my $thisacct=$sth2->fetchrow_hashref();
      $sth2->finish();
      my $newamount = $thisacct->{'amountoutstanding'} + $thisrow->{'amount'};
      $sth2=$dbh->prepare("UPDATE accountlines SET amountoutstanding=? WHERE accountno=?");
      $sth2->execute($newamount,$thisacct->{'accountno'});
      $sth2->finish();
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'borrowernumber'});
      $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,accountno)
             VALUES (?,?,?,?,'Pay',0,?)");
      $sth2->execute($thisrow->{'borrowernumber'}, $thisrow->{'timestamp'},$thisrow->{'amount'},
                    $thisrow->{'description'}, $nextaccntno);
      $sth2->finish();
   }
   elsif ($thisrow->{'accounttype'} eq "TRANSBUS"){
      my $sth2=$dbh->prepare("SELECT accountno,amountoutstanding FROM accountlines
            WHERE borrowernumber = ? AND description = ?");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'f_desc'});
      my $thisacct=$sth2->fetchrow_hashref();
      $sth2->finish();
      my $newamount = $thisacct->{'amountoutstanding'} + $thisrow->{'amount'};
      $sth2=$dbh->prepare("UPDATE accountlines SET amountoutstanding=? WHERE accountno=?");
      $sth2->execute($newamount,$thisacct->{'accountno'});
      $sth2->finish();
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,accountno)
             VALUES (?,?,?,?,'Pay',0,?)");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'timestamp'},$thisrow->{'amount'},
                    "Transfer to Business Office: ".$thisrow->{'f_desc'}, $nextaccntno);
      $sth2->finish();
   }
   elsif ($thisrow->{'accounttype'} eq "LOSTRETURNED"){
      my $sth2=$dbh->prepare("SELECT accountno,amountoutstanding FROM accountlines
            WHERE borrowernumber = ? AND description = ?");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'f_desc'});
      my $thisacct=$sth2->fetchrow_hashref();
      $sth2->finish();
      my $newamount = $thisacct->{'amountoutstanding'} + $thisrow->{'amount'};
      $sth2=$dbh->prepare("UPDATE accountlines SET amountoutstanding=? WHERE accountno=?");
      $sth2->execute($newamount,$thisacct->{'accountno'});
      $sth2->finish();
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,accountno)
             VALUES (?,?,?,?,'Pay',0,?)");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'timestamp'},$thisrow->{'amount'},
                    "Returned Lost Item: ".$thisrow->{'f_desc'}, $nextaccntno);
      $sth2->finish();
   }
   elsif ($thisrow->{'accounttype'} eq "ACCTMANAGE"){
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      my $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,lastincrement,accountno)
             VALUES (?,?,?,?,'A',?,?,?)");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'timestamp'}, $thisrow->{'amount'},
                    $thisrow->{'f_desc'}, $thisrow->{'amount'} , $thisrow->{'amount'} , $nextaccntno);
      $sth2->finish();
   }
   elsif ($thisrow->{'accounttype'} eq "LOSTITEM"){
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      my $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,lastincrement,accountno)
             VALUES (?,?,?,?,'L',?,?,?)");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'timestamp'}, $thisrow->{'amount'},
                    $thisrow->{'f_desc'}, $thisrow->{'amount'} , $thisrow->{'amount'} , $nextaccntno);
      $sth2->finish();
   }
   elsif (($thisrow->{'accounttype'} eq "LOST_SURCHARGE") ||
          ($thisrow->{'accounttype'} eq "RENTAL") ||
          ($thisrow->{'accounttype'} eq "SUNDRY") ||
          ($thisrow->{'accounttype'} eq "CANCELCREDIT") ||
          ($thisrow->{'accounttype'} eq "REFUND") ){
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      my $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,itemnumber,date,amount,description,accounttype,amountoutstanding,lastincrement,accountno)
             VALUES (?,?,?,?,?,'M',?,?,?)");
      $sth2->execute($thisrow->{'f_borr'},$thisrow->{'itemnumber'} , $thisrow->{'timestamp'}, $thisrow->{'amount'},
                    $thisrow->{'f_desc'}, $thisrow->{'amount'} , $thisrow->{'amount'} , $nextaccntno);
      $sth2->finish();
   }
   elsif (($thisrow->{'accounttype'} eq "NEWCARD") ||
          ($thisrow->{'accounttype'} eq "RENEWCARD")){
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      my $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,lastincrement,accountno)
             VALUES (?,?,?,?,'N',?,?,?)");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'timestamp'}, $thisrow->{'amount'},
                    $thisrow->{'f_desc'}, $thisrow->{'amount'} , $thisrow->{'amount'} , $nextaccntno);
      $sth2->finish();
   }
   elsif ($thisrow->{'accounttype'} eq "FORGIVE"){
      my $sth2=$dbh->prepare("SELECT accountno,amountoutstanding FROM accountlines
            WHERE borrowernumber = ? AND description = ?");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'f_desc'});
      my $thisacct=$sth2->fetchrow_hashref();
      $sth2->finish();
      my $newamount = $thisacct->{'amountoutstanding'} + $thisrow->{'amount'};
      $sth2=$dbh->prepare("UPDATE accountlines SET amountoutstanding=? WHERE accountno=?");
      $sth2->execute($newamount,$thisacct->{'accountno'});
      $sth2->finish();
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,accountno)
             VALUES (?,?,?,?,'FOR',0,?)");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'timestamp'},$thisrow->{'amount'},
                    "Forgive: ".$thisrow->{'f_desc'}, $nextaccntno);
      $sth2->finish();
   }
   elsif ($thisrow->{'accounttype'} eq "WRITEOFF"){
      my $sth2=$dbh->prepare("SELECT accountno,amountoutstanding FROM accountlines
            WHERE borrowernumber = ? AND description = ?");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'f_desc'});
      my $thisacct=$sth2->fetchrow_hashref();
      $sth2->finish();
      my $newamount = $thisacct->{'amountoutstanding'} + $thisrow->{'amount'};
      $sth2=$dbh->prepare("UPDATE accountlines SET amountoutstanding=? WHERE accountno=?");
      $sth2->execute($newamount,$thisacct->{'accountno'});
      $sth2->finish();
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'f_borr'});
      $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,accountno)
             VALUES (?,?,?,?,'W',0,?)");
      $sth2->execute($thisrow->{'f_borr'}, $thisrow->{'timestamp'},$thisrow->{'amount'},
                    "Writeoff: ".$thisrow->{'f_desc'}, $nextaccntno);
      $sth2->finish();
   }
   elsif ($thisrow->{'accounttype'} eq "CREDIT"){
      my $nextaccntno = C4::Accounts::getnextacctno($thisrow->{'borrowernumber'});
      my $sth2=$dbh->prepare("INSERT INTO accountlines
            (borrowernumber,date,amount,description,accounttype,amountoutstanding,accountno)
             VALUES (?,?,?,?,'Pay',?,?)");
      $sth2->execute($thisrow->{'borrowernumber'}, $thisrow->{'timestamp'},$thisrow->{'amount'},
                    $thisrow->{'description'}, $thisrow->{'amount'}, $nextaccntno);
      $sth2->finish();
   }
   else {
      print "PROBLEM! \n";
      print "This record did not get processed, because the accounttype is unknown!\n";
      print Dumper($thisrow);
      print "--------------------------\n\n";
   }
}
$sth->finish();

