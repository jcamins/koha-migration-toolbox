#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -backs off database changes to Koha up through LLK 4.02.00.006, if --update is given
#   -need to update to 4.0800003 (jn for LCC migration 5/2012)
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what it would be doing

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

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my $DBversion    = $NULL_STRING;
my $NewDBversion = $NULL_STRING;
my $dbh          = C4::Context->dbh();

#$DBversion    = '';
#$NewDBversion = '';
#if (C4::Context->preference("Version") == TransformToNum($DBversion)){
#   if ($doo_eet) {
#      $dbh->do(qq/
#               /);
#      SetVersion($NewDBversion);
#   }
#   print "Downgrade from $DBversion done.\n";
#}

$DBversion    = '4.02.00.006';
$NewDBversion = '4.02.00.005';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM permissions WHERE code LIKE 'lists%';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.02.00.005';
$NewDBversion = '4.02.00.004';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='FillRequestsAtPickupLibrary';
               /);
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='HoldsTransportationReductionThreshold';
               /);
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='FillRequestsAtPickupLibraryAge';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.02.00.004';
$NewDBversion = '4.02.00.003';
# safely ignore orphaned table.
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='LinkLostItemsToPatron';
               /);
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='RefundReturnedLostItem';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.02.00.003';
$NewDBversion = '4.02.00.002';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='NewPatronReadingHistory';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.02.00.002';
$NewDBversion = '4.02.00.001';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM letter WHERE code='HOLD_CANCELLED' or code='HOLD_PRINT';
               /);
      $dbh->do(qq/
                 DELETE FROM borrower_message_preferences WHERE message_attribute_id=7 or message_attribute_id=8;
               /);
      $dbh->do(qq/
                 DELETE FROM message_transports WHERE message_attribute_id=7 or message_attribute_id=8;
               /);
      $dbh->do(qq/
                 DELETE FROM message_attributes WHERE message_attribute_id=7 or message_attribute_id=8;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.02.00.001';
$NewDBversion = '4.02.00.000';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE labels_layouts DROP COLUMN break_rule_string;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.02.00.000';
$NewDBversion = '4.01.10.000';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE reserves DROP COLUMN displayexpired;
               /);
      $dbh->do(qq/
                 ALTER TABLE old_reserves DROP COLUMN displayexpired;
               /);
      $dbh->do(qq/
                 ALTER TABLE reserves_suspended DROP COLUMN displayexpired;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.10.000';
$NewDBversion = '4.01.00.019';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='MaxShelfHoldsPerDay';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.019';
$NewDBversion = '4.01.00.018';
# MOOT!
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.018';
$NewDBversion = '4.01.00.017';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM permissions WHERE code='relink_items';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.017';
$NewDBversion = '4.01.00.016';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE branches DROP COLUMN branchonshelfholds;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.016';
$NewDBversion = '4.01.00.015';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM letter WHERE code='HOLD_CANCELED';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.015';
$NewDBversion = '4.01.00.014';
# SAFELY IGNORE ORPHANED TABLE
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.014';
$NewDBversion = '4.01.00.013';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='EnableClubsAndServices';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.013';
$NewDBversion = '4.01.00.012';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE borrowers DROP COLUMN exclude_from_collection;
               /);
      $dbh->do(qq/
                 ALTER TABLE deletedborrowers DROP COLUMN exclude_from_collection;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.012';
$NewDBversion = '4.01.00.011';
# MOOT
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.011';
$NewDBversion = '4.01.00.010';
# CAN SAFELY IGNORE CHANGES TO FRAMEWORK
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE subscription DROP COLUMN auto_summarize;
               /);
      $dbh->do(qq/
                 ALTER TABLE subscription DROP COLUMN use_chron;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.010';
$NewDBversion = '4.01.00.009';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE branches DROP COLUMN patronbarcodeprefix;
               /);
      $dbh->do(qq/
                 ALTER TABLE branches DROP COLUMN itembarcodeprefix;
               /);
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='patronbarcodelength';
               /);
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='itembarcodelength';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.009';
$NewDBversion = '4.01.00.008';
# SAFELY IGNORE INDEXES
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.008';
$NewDBversion = '4.01.00.007';
# MOOT
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.007';
$NewDBversion = '4.01.00.006';
# MOOT
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.006';
$NewDBversion = '4.01.00.005';
# SAFELY IGNORE ORPHAN TABLE
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE messages DROP COLUMN checkout_display;
               /);
      $dbh->do(qq/
                 ALTER TABLE messages DROP COLUMN auth_value;
               /);
      $dbh->do(qq/
                 ALTER TABLE messages DROP COLUMN staffnumber;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.005';
$NewDBversion = '4.01.00.004';
# MOOT
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.004';
$NewDBversion = '4.01.00.003';
# MOOT
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.003';
$NewDBversion = '4.01.00.002';
# SAFELY IGNORE CHANGES TO FRAMEWORKS
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.002';
$NewDBversion = '4.01.00.001';
# SAFELY IGNORE AUTHORISED VALUE
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.001';
$NewDBversion = '4.01.00.000';
# SAFELY IGNORE ORPHANED TABLES, AUTHORISED VALUES
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM permissions 
                 WHERE code IN ('manage_courses','put_coursereserves','remove_coursereserves','checkout_via_proxy',
                                'create_proxy_relationships','edit_proxy_relationships','delete_proxy_relationships');
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.01.00.000';
$NewDBversion = '4.00.00.014';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='DisplayStafficonsXSLT';
               /);
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='CourseReserves';
               /);
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable LIKE 'Replica_%';
               /);
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable='OPACAdvancedSearchTypes';
               /);
      $dbh->do(qq/
                 UPDATE systempreferences SET options='itemtypes|ccode' WHERE variable = 'AdvancedSearchTypes';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.014';
$NewDBversion = '4.00.00.013';
# SAFELY IGNORE ORPHANED TABLES
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.013';
$NewDBversion = '4.00.00.012';
# SAFELY IGNORE AUTHORISED VALUE AND PRESENCE OF SUBFIELD, BUT NOT SETTING OF KOHAFIELD
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 UPDATE marc_subfield_structure SET kohafield=NULL WHERE tagfield='952' AND tagsubfield IN ('i','k');
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.012';
$NewDBversion = '4.00.00.011';
# SAFELY IGNORE ORPHANED TABLE
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE items DROP COLUMN suppress;
               /);
      $dbh->do(qq/
                 ALTER TABLE items DROP COLUMN otherstatus;
               /);
      $dbh->do(qq/
                 ALTER TABLE deleteditems DROP COLUMN suppress;
               /);
      $dbh->do(qq/
                 ALTER TABLE deleteditems DROP COLUMN otherstatus;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.011';
$NewDBversion = '4.00.00.010';
# SAFELY IGNORE ORPHANED TABLE
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.010';
$NewDBversion = '4.00.00.009';
# SAFELY IGNORE ORPHANED TABLE
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.009';
$NewDBversion = '4.00.00.008';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE itemtypes DROP COLUMN reservefee;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.008';
$NewDBversion = '4.00.00.007';
# SAFELY IGNORE ORPHANED TABLE
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.007';
$NewDBversion = '4.00.00.006';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE issuingrules DROP COLUMN max_fine;
               /);
      $dbh->do(qq/
                 ALTER TABLE issuingrules DROP COLUMN holdallowed;
               /);
      $dbh->do(qq/
                 ALTER TABLE issuingrules DROP COLUMN max_holds;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.006';
$NewDBversion = '4.00.00.005';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 ALTER TABLE borrowers DROP COLUMN disable_reading_history;
               /);
      $dbh->do(qq/
                 ALTER TABLE borrowers DROP COLUMN amount_notify_date;
               /);
      $dbh->do(qq/
                 ALTER TABLE deletedborrowers DROP COLUMN disable_reading_history;
               /);
      $dbh->do(qq/
                 ALTER TABLE deletedborrowers DROP COLUMN amount_notify_date;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.005';
$NewDBversion = '4.00.00.004';
# MOOT
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.004';
$NewDBversion = '4.00.00.003';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM letter WHERE code='DAMAGEDHOLD';
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.003';
$NewDBversion = '4.00.00.002';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM permissions WHERE code IN 
                 ("bookdrop",
                 "change_circ_date_and_time",
                 "change_due_date",
                 "change_lost_status",
                 "exempt_fines",
                 "fast_add",
                 "override_checkout_max",
                 "override_max_fines",
                 "override_non_circ",
                 "renew_expired",
                 "view_borrower_name_in_checkin",
                 "view_checkout",
                 "add_borrowers",
                 "delete_borrowers",
                 "edit_borrowers",
                 "edit_borrower_circnote",
                 "edit_borrower_opacnote",
                 "view_borrowers",
                 "add_holds",
                 "delete_holds",
                 "delete_waiting_holds",
                 "edit_holds",
                 "reorder_holds",
                 "view_holds",
                 "add_bibliographic",
                 "add_items",
                 "batch_edit_items",
                 "delete_bibliographic",
                 "delete_items",
                 "edit_bibliographic",
                 "view",
                 "accept_payment",
                 "add_charges",
                 "edit_charges",
                 "view_charges",
                 "writeoff_charges",
                 "batch_edit_items");
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.002';
$NewDBversion = '4.00.00.001';
# SAFELY IGNORE
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.001';
$NewDBversion = '4.00.00.000';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
#      $dbh->do(qq/
#                 SET foreign_key_checks=0;
#               /);
      $dbh->do(qq/
                 RENAME TABLE reserves TO harley_reserves;
               /);
      $dbh->do(qq/
                 RENAME TABLE old_reserves TO harley_old_reserves;
               /);
      $dbh->do(qq/
                 CREATE TABLE `reserves` (
                   `borrowernumber` int(11) NOT NULL DEFAULT '0',
                   `reservedate` date DEFAULT NULL,
                   `biblionumber` int(11) NOT NULL DEFAULT '0',
                   `constrainttype` varchar(1) DEFAULT NULL,
                   `branchcode` varchar(10) DEFAULT NULL,
                   `notificationdate` date DEFAULT NULL,
                   `reminderdate` date DEFAULT NULL,
                   `cancellationdate` date DEFAULT NULL,
                   `reservenotes` mediumtext,
                   `priority` smallint(6) DEFAULT NULL,
                   `found` varchar(1) DEFAULT NULL,
                   `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                   `itemnumber` int(11) DEFAULT NULL,
                   `waitingdate` date DEFAULT NULL,
                   `expirationdate` date DEFAULT NULL,
                   `lowestPriority` tinyint(1) NOT NULL,
                   KEY `borrowernumber` (`borrowernumber`),
                   KEY `biblionumber` (`biblionumber`),
                   KEY `itemnumber` (`itemnumber`),
                   KEY `branchcode` (`branchcode`),
                   KEY `priorityfoundidx` (`priority`,`found`)
                 ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
               /);
      $dbh->do(qq/
                 CREATE TABLE `old_reserves` (
                   `borrowernumber` int(11) DEFAULT NULL,
                   `reservedate` date DEFAULT NULL,
                   `biblionumber` int(11) DEFAULT NULL,
                   `constrainttype` varchar(1) DEFAULT NULL,
                   `branchcode` varchar(10) DEFAULT NULL,
                   `notificationdate` date DEFAULT NULL,
                   `reminderdate` date DEFAULT NULL,
                   `cancellationdate` date DEFAULT NULL,
                   `reservenotes` mediumtext,
                   `priority` smallint(6) DEFAULT NULL,
                   `found` varchar(1) DEFAULT NULL,
                   `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                   `itemnumber` int(11) DEFAULT NULL,
                   `waitingdate` date DEFAULT NULL,
                   `expirationdate` date DEFAULT NULL,
                   `lowestPriority` tinyint(1) NOT NULL,
                   KEY `old_reserves_borrowernumber` (`borrowernumber`),
                   KEY `old_reserves_biblionumber` (`biblionumber`),
                   KEY `old_reserves_itemnumber` (`itemnumber`),
                   KEY `old_reserves_branchcode` (`branchcode`)
                 ) ENGINE=InnoDB DEFAULT CHARSET=utf8
               /);
#      $dbh->do(qq/
#                 SET foreign_key_checks = 0;
#               /);
#      $dbh->do(qq/
#                 ALTER TABLE reserves ADD CONSTRAINT `reserves_ibfk_1` 
#                   FOREIGN KEY (`borrowernumber`) 
#                   REFERENCES `borrowers` (`borrowernumber`) 
#                   ON DELETE CASCADE ON UPDATE CASCADE;
#               /);
#      $dbh->do(qq/
#                 ALTER TABLE reserves ADD CONSTRAINT `reserves_ibfk_2` 
#                   FOREIGN KEY (`biblionumber`) 
#                   REFERENCES `biblio` (`biblionumber`) 
#                   ON DELETE CASCADE ON UPDATE CASCADE;
#               /);
#      $dbh->do(qq/
#                 ALTER TABLE reserves ADD CONSTRAINT `reserves_ibfk_3` 
#                   FOREIGN KEY (`itemnumber`) 
#                   REFERENCES `items` (`itemnumber`) 
#                   ON DELETE CASCADE ON UPDATE CASCADE;
#               /);
#      $dbh->do(qq/
#                 ALTER TABLE reserves ADD CONSTRAINT `reserves_ibfk_4` 
#                   FOREIGN KEY (`branchcode`) 
#                   REFERENCES `branches` (`branchcode`) 
#                   ON DELETE CASCADE ON UPDATE CASCADE;
#               /);
#      $dbh->do(qq/
#                 ALTER TABLE old_reserves ADD CONSTRAINT `old_reserves_ibfk_1` 
#                   FOREIGN KEY (`borrowernumber`) 
#                   REFERENCES `borrowers` (`borrowernumber`) 
#                   ON DELETE SET NULL ON UPDATE SET NULL;
#               /);
#      $dbh->do(qq/
#                 ALTER TABLE old_reserves ADD CONSTRAINT `old_reserves_ibfk_2` 
#                   FOREIGN KEY (`biblionumber`) 
#                   REFERENCES `biblio` (`biblionumber`) 
#                   ON DELETE SET NULL ON UPDATE SET NULL;
#               /);
#      $dbh->do(qq/
#                 ALTER TABLE old_reserves ADD CONSTRAINT `old_reserves_ibfk_3` 
#                   FOREIGN KEY (`itemnumber`) 
#                   REFERENCES `items` (`itemnumber`) 
#                   ON DELETE SET NULL ON UPDATE SET NULL;
#               /);
      $dbh->do(qq/
                 INSERT INTO reserves
                    (borrowernumber,reservedate,biblionumber,constrainttype,branchcode,notificationdate,
                     reminderdate,cancellationdate,reservenotes,priority,found,timestamp,itemnumber,waitingdate)
                    SELECT borrowernumber,reservedate,biblionumber,constrainttype,branchcode,notificationdate,
                     reminderdate,cancellationdate,reservenotes, priority,found,timestamp,itemnumber,waitingdate FROM harley_reserves;
               /);
      $dbh->do(qq/
                 INSERT INTO old_reserves
                    (borrowernumber,reservedate,biblionumber,constrainttype,branchcode,notificationdate,
                     reminderdate,cancellationdate,reservenotes,priority,found,timestamp,itemnumber,waitingdate)
                    SELECT borrowernumber,reservedate,biblionumber,constrainttype,branchcode,notificationdate,
                     reminderdate,cancellationdate,reservenotes, priority,found,timestamp,itemnumber,waitingdate FROM harley_old_reserves;
               /);
      $dbh->do(qq/
                 SET foreign_key_checks = 1;
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

$DBversion    = '4.00.00.000';
$NewDBversion = '3.01.00.061';
if (C4::Context->preference("Version") == TransformToNum($DBversion)){
   if ($doo_eet) {
      $dbh->do(qq/
                 DELETE FROM systempreferences WHERE variable IN 
                 ("AllowCheckInDateChange",
                  "AllowDueDateInPast",
                  "AllowMultipleHoldsPerBib",
                  "AllowOverrideLogin",
                  "AllowReadingHistoryAnonymizing",
                  "AnonymousPatron",
                  "BatchMemberDeleteFineThreshhold",
                  "BatchMemberDeletePaidDebtCollections",
                  "BCCAllNotices",
                  "calcFineOnReturn",
                  "CheckoutTimeout",
                  "CircFinesBreakdown",
                  "ClaimedReturnToLost",
                  "ClaimsReturnedValue",
                  "DisableHoldsIssueOverrideUnlessAuthorised",
                  "DisallowItemLevelOnShelfHolds",
                  "DisplayInitials",
                  "DisplayOthernames",
                  "EnableOverdueAccruedAmount",
                  "EnableOwedNotification",
                  "FineOnClaimsReturned",
                  "HoldButtonConfirm",
                  "HoldButtonIgnore",
                  "HoldButtonPrintConfirm",
                  "LinkLostItemsToPatron",
                  "LongOverdueToLost",
                  "MarkLostItemsReturned",
                  "opacbookbagName",
                  "opacmsgtab",
                  "OPACNewBooks",
                  "OPACNewBooksDays",
                  "OPACNewBooksHeader",
                  "OPACNewBooksMaxList",
                  "OPACNewBooksTypesExcluded",
                  "OPACSearchSuggestionsCount",
                  "OwedNotificationValue",
                  "PatronDisplayReturn",
                  "ReservesControlBranch",
                  "ResetOpacInactivityTimeout",
                  "ShowPatronSearchBySQL",
                  "StaffSearchSuggestionsCount",
                  "TalkingTechEnabled",
                  "TalkingTechMessagePath",
                  "UseGranularMaxFines",
                  "UseGranularMaxHolds",
                  "WarnOnlyOnMaxFine");
               /);
      SetVersion($NewDBversion);
   }
   print "Downgrade from $DBversion done.\n";
}

exit;

sub TransformToNum {
    my $version = shift;
    # remove the 3 last . to have a Perl number
    $version =~ s/(.*\..*)\.(.*)\.(.*)/$1$2$3/;
    return $version;
}

sub SetVersion {
    my $kohaversion = TransformToNum(shift);
    if (C4::Context->preference('Version')) {
      my $finish=$dbh->prepare("UPDATE systempreferences SET value=? WHERE variable='Version'");
      $finish->execute($kohaversion);
    } else {
      my $finish=$dbh->prepare("INSERT into systempreferences (variable,value,explanation) 
                                VALUES ('Version',?,
                        'The Koha database version. WARNING: Do not change this value manually, it is maintained by the webinstaller')");
      $finish->execute($kohaversion);
    }
}
exit;

