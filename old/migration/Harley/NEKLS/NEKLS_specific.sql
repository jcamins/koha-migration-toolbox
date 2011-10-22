UPDATE borrowers SET categorycode="ASSOCIATE" where categorycode = "STAFF" and surname != "CIRC" and surname != "TECH" and surname != "DIRECTOR" and userid != "AGSIP" and userid NOT LIKE "SIP%";
UPDATE borrowers SET categorycode="ASSOCIATE" where categorycode = "OTT-FAMILY" and surname != "CIRC" and surname != "TECH" and surname != "DIRECTOR" and userid != "AGSIP" and userid NOT LIKE "SIP%";
DELETE FROM categories WHERE categorycode = "OTT-FAMILY";

CREATE TABLE sessions (
  `id` varchar(32) NOT NULL,
  `a_session` text NOT NULL,
  UNIQUE KEY id (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `action_logs` (
  `action_id` int(11) NOT NULL auto_increment,
  `timestamp` timestamp NOT NULL default CURRENT_TIMESTAMP on update CURRENT_TIMESTAMP,
  `user` int(11) NOT NULL default 0,
  `module` text,
  `action` text,
  `object` int(11) default NULL,
  `info` text,
  PRIMARY KEY (`action_id`),
  KEY  (`timestamp`,`user`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE `zebraqueue` (
  `id` int(11) NOT NULL auto_increment,
  `biblio_auth_number` bigint(20) unsigned NOT NULL default '0',
  `operation` char(20) NOT NULL default '',
  `server` char(20) NOT NULL default '',
  `done` int(11) NOT NULL default '0',
  `time` timestamp NOT NULL default CURRENT_TIMESTAMP,
  PRIMARY KEY  (`id`),
  KEY `zebraqueue_lookup` (`server`, `biblio_auth_number`, `operation`, `done`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
CREATE TABLE `message_queue` (
  `message_id` int(11) NOT NULL AUTO_INCREMENT,
  `borrowernumber` int(11) DEFAULT NULL,
  `subject` text,
  `content` text,
  `metadata` text,
  `letter_code` varchar(64) DEFAULT NULL,
  `message_transport_type` varchar(20) NOT NULL,
  `status` enum('sent','pending','failed','deleted') NOT NULL DEFAULT 'pending',
  `time_queued` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `to_address` mediumtext,
  `from_address` mediumtext,
  `content_type` text,
  KEY `message_id` (`message_id`),
  KEY `borrowernumber` (`borrowernumber`),
  KEY `message_transport_type` (`message_transport_type`),
  CONSTRAINT `messageq_ibfk_1` FOREIGN KEY (`borrowernumber`) REFERENCES `borrowers` (`borrowernumber`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `messageq_ibfk_2` FOREIGN KEY (`message_transport_type`) REFERENCES `message_transport_types` (`message_transport_type`) ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

update issuingrules set renewalsallowed=1;
update issuingrules set reservesallowed=100;
delete from biblio where biblionumber not in (select distinct biblionumber from items) and datecreated<"2011-02-28";
update borrowers set flags=117856 where surname = "TECH";
update borrowers set flags=1110 where surname = "CIRC";
update borrowers set flags=248918 where surname = "DIRECTOR";
