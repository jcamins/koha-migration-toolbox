#!/usr/bin/perl
use C4::Context;
use C4::Accounts;
use strict;
use Data::Dumper;

my $dbh= C4::Context::dbh();

my $sth=$dbh->prepare("RENAME TABLE old_issues TO lek_old_issues");
$sth->execute();
my $sth=$dbh->prepare("DROP TABLE IF EXISTS old_issues;");
$sth->execute();

$sth=$dbh->prepare(" CREATE TABLE `old_issues` (
  `borrowernumber` int(11) default NULL,
  `itemnumber` int(11) default NULL,
  `date_due` date default NULL,
  `branchcode` varchar(10) default NULL,
  `issuingbranch` varchar(18) default NULL,
  `returndate` date default NULL,
  `lastreneweddate` date default NULL,
  `return` varchar(4) default NULL,
  `renewals` tinyint(4) default NULL,
  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `issuedate` date default NULL,
  KEY `old_issuesborridx` (`borrowernumber`),
  KEY `old_issuesitemidx` (`itemnumber`),
  KEY `old_bordate` (`borrowernumber`,`timestamp`),
  CONSTRAINT `old_issues_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
    ON DELETE SET NULL ON UPDATE SET NULL,
  CONSTRAINT `old_issues_ibfk_2` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`)
    ON DELETE SET NULL ON UPDATE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;");
$sth->execute();

$sth=$dbh->prepare("INSERT INTO old_issues
                    (borrowernumber,itemnumber,branchcode,
                     issuedate, date_due,returndate,renewals,lastreneweddate)
                    SELECT borrowernumber,itemnumber,branchcode,
                     issuedate,duedate,returndate,renewals,lastreneweddate
                    FROM lek_old_issues;");
$sth->execute();
