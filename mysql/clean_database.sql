#---------------------------------
# Copyright 2010 ByWater Solutions
#---------------------------------
#
# This script will clear out a Koha database, leaving configuration
# information alone, and allow privileged staff users only. 
# 
# USE WITH EXTREME CAUTION!
#

SET FOREIGN_KEY_CHECKS=0;
DELETE FROM borrowers WHERE flags IS NULL;
DELETE FROM borrowers WHERE flags=0;
DELETE FROM borrower_message_preferences WHERE borrowernumber IS NOT NULL;
TRUNCATE patroncards;
TRUNCATE patronimage;
TRUNCATE borrower_attributes;
TRUNCATE action_logs; 
TRUNCATE aqbasket;
TRUNCATE aqbasketgroups;
TRUNCATE aqbooksellers;
TRUNCATE aqbudgetperiods;
TRUNCATE aqbudgets;
TRUNCATE aqbudgets_planning;
TRUNCATE aqcontract;
TRUNCATE aqorderdelivery;
TRUNCATE aqorders;
TRUNCATE aqorders_items;
TRUNCATE aqorders; 
TRUNCATE aqorderdelivery;
TRUNCATE branchtransfers;
TRUNCATE tmp_holdsqueue; 
TRUNCATE deleteditems; 
TRUNCATE deletedbiblioitems; 
TRUNCATE deletedbiblio; 
TRUNCATE deletedborrowers;
TRUNCATE import_batches; 
TRUNCATE import_biblios; 
TRUNCATE import_items;
TRUNCATE import_record_matches; 
TRUNCATE import_records;
TRUNCATE issues; 
TRUNCATE message_queue;
TRUNCATE old_issues; 
TRUNCATE reserves; 
TRUNCATE old_reserves;
TRUNCATE statistics;
TRUNCATE accountlines; 
TRUNCATE reviews; 
TRUNCATE serial; 
TRUNCATE subscription; 
TRUNCATE subscriptionhistory; 
TRUNCATE subscriptionroutinglist; 
TRUNCATE tags;
TRUNCATE tags_all;
TRUNCATE tags_approval;
TRUNCATE tags_index;
TRUNCATE virtualshelves; 
TRUNCATE virtualshelfcontents;
TRUNCATE auth_header;
TRUNCATE zebraqueue; 
TRUNCATE items; 
TRUNCATE biblioitems; 
TRUNCATE biblio;
SET FOREIGN_KEY_CHECKS=1;
