
# Summary holdings

drop table summaries;
drop table unstructured_summary_holdings_statements;
drop table structured_summary_holdings_statements;
drop table structured_summary_holdings_statement_levels;
drop table summary_record_templates;
drop table import_summaries;
alter table items drop foreign key items_ibfk_4;
alter table items drop column summary_id;
alter table deleteditems drop column summary_id;
alter table import_batches drop column num_summaries;
delete from permissions where code="create_summary";
delete from permissions where code="delete_summary";
delete from permissions where code="update_summary";

# Proxy borrowing

alter table issues drop foreign key issues_ibfk_3;
alter table issues remove key proxy_borrowernumber;
alter table issues drop column proxy_borrowernumber;
alter table old_issues drop foreign key issues_ibfk_3;
alter table old_issues remove key proxy_borrowernumber;
alter table old_issues drop column proxy_borrowernumber;
drop table proxy_relationships;
delete from letter where module="proxy_relationship";
delete from message_attributes where message_name like "Proxy%";
delete from message_transports where letter_module="proxy_relationship";

# Fine thresholds

drop table fine_thresholds;
delete from permissions where code="fine_threshold_forgive";

# Fines structure

drop table accounttypes;
drop table fees;
drop table payments;
drop table fee_transactions;

# Term loans

drop table circ_termsets;
drop table circ_term_dates;

# Issuing Rules

drop table fees_accruing;
drop table circ_rules;
drop table circ_policies;
drop table library_hours;
alter table reserves drop column policy_override;
alter table old_reserves drop column policy_override;
delete from systempreferences where variable="TimeFormat";

# Call slips

drop table callslips;
alter table default_circ_rules drop column max_callslip;
alter table default_circ_rules drop column max_doc_del;
alter table default_branch_circ_rules drop column max_callslip;
alter table default_branch_circ_rules drop column max_doc_del;
alter table default_borrower_circ_rules drop column max_callslip;
alter table default_borrower_circ_rules drop column max_doc_del;
alter table branch_borrower_circ_rules drop column max_callslip;
alter table branch_borrower_circ_rules drop column max_doc_del;
delete from systempreferences where variable="CallslipMode";

# xtags

drop table xtags;
drop table xtags_and_saved_sql;
alter table saved_sql drop column metadata;

# barcode prefix

alter table branches drop column itembarcodeprefis;
alter table branches drop column patronbarcodeprefix;
delete from systempreferences where variable="itembarcodelength";
delete from systempreferences where variable="patronbarcodelength";

# subscription foreign keys

alter table serial drop foreign key serial_fk_1;
alter table subscription drop foreign key subscription_fk_1;

# borrowers

alter table borrowers drop column timestamp;
alter table deleted borrowers drop column timestamp;

# files?

drop table files;

# course reserves

delete from authorised_values where category="DEPARTMENT";
delete from authorised_values where category="TERM";
drop table instructor_course_link;
drop table course_reserves;
drop table courses;
delete from systempreferences where variable="CourseReserves";
delete from permissions where code="manages_courses";
delete from permissions where code="put_coursereserves";
delete from permissions where code="remove_coursereserves";

# moving stuff back to sysprefs

INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('noissuescharge',5,'Define maximum amount withstanding before check outs are blocked','','Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('maxoutstanding',5,'maximum amount withstanding to be able make holds','','Integer');
INSERT INTO `systempreferences` (variable,value,explanation,options,type) VALUES('maxreserves',50,'Define maximum number of holds a patron can place','','Integer');
alter table categories drop column circ_block_threshold;
alter table categories drop column holds_block_threshold;
alter table categories drop column maxholds;

# circ_exceptions

drop table circ_exceptions;

# recalls

drop table recall rules;
delete from letter where code="recall";
alter table issues drop column recall_policy_id;
alter table old_issues drop column recall_policy_id;

# attributes

drop table attributes;
drop table attributes_tracking;

# assorted sysprefs

delete from systempreferences where variable="ChargeFineOnRenewal";
delete from systempreferences where variable="LongOverdueSettings";
delete from systempreferences where variable="HoldsQueueSchedule";
delete from systempreferences where variable="StaffClientMaintenance";
delete from systempreferences where variable="Sandbox";
delete from systempreferences where variable="MaxLostSurchargePerDay";
delete from systempreferences where variable="DisplayWhichLibraryOnDetailPage";
delete from systempreferences where variable="PreventDeletingBibWithItems";
delete from systempreferences where variable="WarnWhenDeletingBibWithItems";
delete from systempreferences where variable="RefundSurchargeWhenLostItemChargeRefunded";
delete from systempreferences where variable="AllowSelfRenew";
delete from systempreferences where variable="AllowSelfReturn";
delete from systempreferences where variable like "%Music%";
delete from systempreferences where variable="BasicSearchSyntax";
delete from systempreferences where variable="TZ";

# permissions

delete from permissions where code="search_deleted";
delete from permissions where code="batch_item_edit";
delete from permissions where code="batch_item_delete";
delete from permissions where code="access";
delete from permissions where code="fast_add";
delete from permissions where code="basic_edit";

