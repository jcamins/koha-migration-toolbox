#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# This script loads files of fines from VTLS Virtua
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use Getopt::Long;
use C4::Context;
use C4::Accounts;

my $infile_name = "";

GetOptions(
    'in=s'     => \$infile_name,
);

if (($infile_name eq '')){
    print << 'ENDUSAGE';

Usage:  fines_import --in=<infile> 

<infile>     A pipe-formatted data file, with header row containing fieldnames.

ENDUSAGE
exit;
}

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

my $sth2=$dbh->prepare("INSERT INTO accountlines
                       (borrowernumber,itemnumber,date,amount,description,accounttype,amountoutstanding,lastincrement,accountno)
                        VALUES (?,?,?,?,?,?,?,?,?)");

open INFL,"<$infile_name";
my $dum=readline(INFL);
while (my $line=readline(INFL)){
    chomp $line;
    my ($itmbar,$patronbar,$duedate,$finedate,$amount,$amountoutstanding,$code,undef) = split(/\|/,$line);
    my $itemnum = "";
    my $borrowernum = "";
    if ($itmbar){
        my $convertq = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode = '$itmbar';");
        $convertq->execute();
        $itemnum = $convertq->fetchrow_arrayref()->[0] || "";
    }
    if ($patronbar){
        my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = $patronbar;");
        $convertq->execute();
        $borrowernum = $convertq->fetchrow_arrayref()->[0];
    }

    $duedate =~ s/(\d{4})(\d{2})(\d{2})/$1-$2-$3/;
    my $description = "";
    my $finetype = "";
    if ($code eq "Item Price Fee"){
        $description = "Lost item $itmbar due $duedate";
        $finetype = "L";
    }
    if ($code eq "Processing Fee"){
        $description = "Processing fee for lost item $itmbar";
        $finetype = "M";
    }
    
    $finedate =~ s/(\d{4})(\d{2})(\d{2})/$1-$2-$3/;

    my $nextaccntno = C4::Accounts::getnextacctno($borrowernum);
    $sth2->execute($borrowernum,$itemnum,$finedate,$amount,$description,$finetype,$amountoutstanding,$amount,$nextaccntno);
}

