# for LAK v4.06.00.001 and earlier

ALTER TABLE aqbooksellers DROP COLUMN deliverydays;
ALTER TABLE aqbooksellers DROP COLUMN followupdays;
ALTER TABLE aqbooksellers DROP COLUMN followupscancel;
ALTER TABLE aqbooksellers DROP COLUMN specialty;
ALTER TABLE aqbooksellers DROP COLUMN nocalc;
ALTER TABLE aqbooksellers DROP COLUMN invoicedisc;

ALTER TABLE authorised_values CHANGE opaclib lib_opac varchar(80) AFTER lib;

ALTER TABLE biblioitems DROP COLUMN on_order_count;
ALTER TABLE biblioitems DROP COLUMN in_process_count;

ALTER TABLE borrowers DROP COLUMN timestamp;

ALTER TABLE branch_borrower_circ_rules DROP COLUMN max_callslip;
ALTER TABLE branch_borrower_circ_rules DROP COLUMN max_doc_del;

ALTER TABLE branches DROP COLUMN itembarcodeprefix;
ALTER TABLE branches DROP COLUMN patronbarcodeprefix;

DROP TABLE callslips;

ALTER TABLE default_borrower_circ_rules DROP COLUMN max_callslip;
ALTER TABLE default_borrower_circ_rules DROP COLUMN max_doc_del;

ALTER TABLE default_branch_circ_rules DROP COLUMN max_callslip;
ALTER TABLE default_branch_circ_rules DROP COLUMN max_doc_del;

ALTER TABLE default_circ_rules DROP COLUMN max_callslip;
ALTER TABLE default_circ_rules DROP COLUMN max_doc_del;

ALTER TABLE import_batches DROP COLUMN num_summaries;

DROP TABLE import_summaries;

ALTER TABLE items CHANGE itemtype itype varchar(10);
ALTER TABLE items DROP COLUMN summary_id;
ALTER TABLE items DROP COLUMN catstat;

ALTER TABLE old_reserves DROP COLUMN policy_override;

ALTER TABLE reserves DROP COLUMN policy_override;

ALTER TABLE saved_sql DROP COLUMN metadata;

DROP TABLE structured_summary_holdings_statement_levels;
DROP TABLE structured_summary_holdings_statements;


