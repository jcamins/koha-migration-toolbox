#!/usr/bin/perl
use C4::Context;
use C4::Accounts;
use strict;
use Data::Dumper;

my $dbh= C4::Context::dbh();

my $sth=$dbh->prepare("ALTER TABLE circ_policies DROP FOREIGN KEY circ_policies_fk_1");
#$sth->execute();
my $sth=$dbh->prepare("ALTER TABLE circ_policies DROP COLUMN branchcode");
#$sth->execute();
my $sth=$dbh->prepare("DROP TABLE IF EXISTS issuingrules;");
$sth->execute();

$sth=$dbh->prepare(" CREATE TABLE `issuingrules` (
  `categorycode` varchar(10) NOT NULL default '',
  `itemtype` varchar(10) NOT NULL default '',
  `restrictedtype` tinyint(1) default NULL,
  `rentaldiscount` decimal(28,6) default NULL,
  `reservecharge` decimal(28,6) default NULL,
  `fine` decimal(28,6) default NULL,
  `finedays` int(11) default NULL,
  `firstremind` int(11) default NULL,
  `chargeperiod` int(11) default NULL,
  `accountsent` int(11) default NULL,
  `chargename` varchar(100) default NULL,
  `maxissueqty` int(4) default NULL,
  `issuelength` int(4) default NULL,
  `renewalsallowed` smallint(6) NOT NULL default 0,
  `reservesallowed` smallint(6) NOT NULL default 0,
  `branchcode` varchar(10) NOT NULL default '',
  PRIMARY KEY  (`branchcode`,`categorycode`,`itemtype`),
  KEY `categorycode` (`categorycode`),
  KEY `itemtype` (`itemtype`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8");
$sth->execute();

$sth=$dbh->prepare("SELECT
                    circ_rules.branchcode,circ_rules.itemtype,circ_rules.categorycode,circ_policies.* FROM circ_rules 
                    LEFT JOIN circ_policies 
                    ON (circ_rules.circ_policies_id = circ_policies.id)
                    WHERE loan_type = 'daily'");
$sth->execute();

my $counter=0;
my $sth2=$dbh->prepare("INSERT INTO issuingrules
                        (branchcode,categorycode,itemtype,
                         fine,firstremind,chargeperiod,
                         maxissueqty,issuelength,renewalsallowed) 
                         VALUES (?,?,?,?,?,?,?,?,?)");
while (my $row=$sth->fetchrow_hashref()){
   $counter++;
   if ($counter%100==0) {
      print "$counter records processed...\n";
   }
   $row->{branchcode} = "*" if (!$row->{branchcode});
   $row->{categorycode} = "*" if (!$row->{categorycode});
   $row->{itemtype} = "*" if (!$row->{itemtype});
   $row->{maxrenewals} = 0 if (!$row->{maxrenewals});
   $sth2->execute(  $row->{branchcode},
                    $row->{categorycode},
                    $row->{itemtype},
                    $row->{overdue_fine},
                    $row->{grace_period},
                    $row->{fine_period},
                    $row->{maxissueqty},
                    $row->{issue_length},
                    $row->{maxrenewals} );
}
$sth->finish();
