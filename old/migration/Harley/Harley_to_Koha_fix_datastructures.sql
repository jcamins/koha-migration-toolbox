
SET foreign_key_checks=0;

RENAME TABLE reserves TO harley_reserves;
RENAME TABLE old_reserves TO harley_old_reserves;

CREATE TABLE `reserves` (
  `borrowernumber` int(11) default NULL,
  `reservedate` date default NULL,
  `biblionumber` int(11) default NULL,
  `constrainttype` varchar(1) default NULL,
  `branchcode` varchar(10) default NULL,
  `notificationdate` date default NULL,
  `reminderdate` date default NULL,
  `cancellationdate` date default NULL,
  `reservenotes` mediumtext,
  `priority` smallint(6) default NULL,
  `found` varchar(1) default NULL,
  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `itemnumber` int(11) default NULL,
  `waitingdate` date default NULL,
  `expirationdate` DATE DEFAULT NULL,
  KEY `old_reserves_borrowernumber` (`borrowernumber`),
  KEY `old_reserves_biblionumber` (`biblionumber`),
  KEY `old_reserves_itemnumber` (`itemnumber`),
  KEY `old_reserves_branchcode` (`branchcode`),
  CONSTRAINT `reserves_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
    ON DELETE SET NULL ON UPDATE SET NULL,
  CONSTRAINT `reserves_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`)
    ON DELETE SET NULL ON UPDATE SET NULL,
  CONSTRAINT `reserves_ibfk_3` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`)
    ON DELETE SET NULL ON UPDATE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE `old_reserves` (
  `borrowernumber` int(11) default NULL,
  `reservedate` date default NULL,
  `biblionumber` int(11) default NULL,
  `constrainttype` varchar(1) default NULL,
  `branchcode` varchar(10) default NULL,
  `notificationdate` date default NULL,
  `reminderdate` date default NULL,
  `cancellationdate` date default NULL,
  `reservenotes` mediumtext,
  `priority` smallint(6) default NULL,
  `found` varchar(1) default NULL,
  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `itemnumber` int(11) default NULL,
  `waitingdate` date default NULL,
  `expirationdate` DATE DEFAULT NULL,
  KEY `old_reserves_borrowernumber` (`borrowernumber`),
  KEY `old_reserves_biblionumber` (`biblionumber`),
  KEY `old_reserves_itemnumber` (`itemnumber`),
  KEY `old_reserves_branchcode` (`branchcode`),
  CONSTRAINT `old_reserves_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`)
    ON DELETE SET NULL ON UPDATE SET NULL,
  CONSTRAINT `old_reserves_ibfk_2` FOREIGN KEY (`biblionumber`) REFERENCES `biblio` (`biblionumber`)
    ON DELETE SET NULL ON UPDATE SET NULL,
  CONSTRAINT `old_reserves_ibfk_3` FOREIGN KEY (`itemnumber`) REFERENCES `items` (`itemnumber`)
    ON DELETE SET NULL ON UPDATE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
INSERT INTO reserves
   (borrowernumber,reservedate,biblionumber,constrainttype,branchcode,notificationdate,reminderdate,cancellationdate,reservenotes,
    priority,found,timestamp,itemnumber,waitingdate) 
   SELECT borrowernumber,reservedate,biblionumber,constrainttype,branchcode,notificationdate,reminderdate,cancellationdate,reservenotes,
    priority,found,timestamp,itemnumber,waitingdate FROM harley_reserves;
INSERT INTO old_reserves
   (borrowernumber,reservedate,biblionumber,constrainttype,branchcode,notificationdate,reminderdate,cancellationdate,reservenotes,
    priority,found,timestamp,itemnumber,waitingdate) 
   SELECT borrowernumber,reservedate,biblionumber,constrainttype,branchcode,notificationdate,reminderdate,cancellationdate,reservenotes,
    priority,found,timestamp,itemnumber,waitingdate FROM harley_old_reserves;


