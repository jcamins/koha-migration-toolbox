#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use C4::Context;
use MARC::Record;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $written = 0;
my $problem = 0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my %queries = (
   "01-biblio.mrc" => "SELECT marc FROM biblioitems",
   "02-items.csv" => "SELECT itemnumber,biblionumber,barcode,dateaccessioned,booksellerid,homebranch,price,replacementprice,
                             replacementpricedate,datelastborrowed,datelastseen,stack,notforloan,damaged,itemlost,wthdrawn,itemcallnumber,
                             issues,renewals,reserves,restricted,itemnotes,holdingbranch,paidfor,timestamp,location,onloan,cn_source,
                             ccode,materials,uri,itemtype,enumchron,copynumber 
                      FROM items",
   "02a-items.csv" => "SELECT itemnumber,biblionumber,barcode,dateaccessioned,booksellerid,homebranch,price,replacementprice,
                              replacementpricedate,datelastborrowed,datelastseen,stack,notforloan,damaged,itemlost,wthdrawn,itemcallnumber,
                              issues,renewals,reserves,restricted,itemnotes,holdingbranch,paidfor,timestamp,location,onloan,cn_source,
                              ccode,materials,uri,itype,enumchron,copynumber 
                       FROM items",
   "03-accountlines.csv" => "SELECT cardnumber, accountno, barcode, date, amount, description, dispute, accounttype, amountoutstanding, 
                                    notify_id, notify_level, lastincrement 
                             FROM accountlines
                             LEFT JOIN borrowers USING (borrowernumber)
                             LEFT JOIN items USING (itemnumber)",
   "04-accountoffsets.csv" => "SELECT cardnumber, accountno, offsetaccount, offsetamount 
                               FROM accountoffsets 
                               LEFT JOIN borrowers USING (borrowernumber)",
   "03a-newfees.csv" => "SELECT fee_id, payment_id, accounttype,amount, fee_transactions.timestamp, b.cardnumber as f_borr, barcode,
                                fees.description as f_desc, b2.cardnumber as p_borr, payments.branchcode, payments.description as p_desc,
                                payment_type, payments.date, received_by
                         FROM fee_transactions
                         LEFT JOIN fees ON (fee_id=fees.id)
                         LEFT JOIN payments ON (payment_id=payments.id)
                         LEFT JOIN borrowers b ON (fees.borrowernumber=b.borrowernumber)
                         LEFT JOIN borrowers b2 ON (payments.borrowernumber=b2.borrowernumber)
                         LEFT JOIN items USING (itemnumber)
                         ORDER BY timestamp",
#9212012 added 03b as above query misses payments that are credits and not associated with any fees in fees table. (no feeid)
   "03b-newfees_credits.csv" => "SELECT p.id, ft.accounttype, ft.amount, ft.timestamp, b.cardnumber as f_borr, p.description as f_desc, 
                                        p.branchcode, p.payment_type, p.date, p.received_by  
                                 FROM  payments p 
                                 LEFT JOIN borrowers b on (p.borrowernumber=b.borrowernumber) 
                                 LEFT JOIN fee_transactions ft on (p.id=ft.payment_id) 
                                 WHERE ft.fee_id is NULL and p.payment_type ='CREDIT'",
   "05-aqbasket.csv" => "SELECT basketno, creationdate, closedate, booksellerid, cardnumber as authorisedby, booksellerinvoicenumber
                         FROM aqbasket  
                         LEFT JOIN borrowers on (aqbasket.authorisedby=borrowers.borrowernumber)",
   "06-aqbooksellers.csv" => "SELECT id, name, address1, address2, address3, address4, phone, accountnumber, othersupplier, currency, 
                                     booksellerfax, notes, bookselleremail, booksellerurl, contact, postal, url, contpos, contphone, 
                                     contfax, contaltphone, contemail, contnotes, active, listprice, invoiceprice, gstreg, listincgst, 
                                     invoiceincgst, discount, fax
                              FROM aqbooksellers",
   "07-aqbudgetperiods.csv" => "SELECT b.aqbudgetid as budget_period_id, b.startdate as budget_period_startdate, 
                                       b.enddate as budget_period_enddate, b.budgetamount as budget_period_total, 
                                       f.bookfundname as budget_period_descriptiion 
                                FROM aqbudget b, aqbookfund f 
                                WHERE b.bookfundid=f.bookfundid",
   "08-aqbudgets.csv" => "SELECT b.aqbudgetid as budget_period_id, b.budgetamount as budget_amount, f.bookfundname as budget_name, 
                                 f.branchcode as budget_branchcode, concat(b.bookfundid,b.aqbudgetid) as budget_code
                          FROM aqbudget b, aqbookfund f
                          WHERE b.bookfundid=f.bookfundid",
   "09-aqorders.csv" => "SELECT o.ordernumber, o.biblionumber, o.entrydate, o.quantity, o.currency, o.listprice, o.totalamount, 
                                o.datereceived, o.booksellerinvoicenumber, o.freight, o.unitprice, o.quantityreceived, o.cancelledby, 
                                o.datecancellationprinted, o.notes, o.supplierreference, o.purchaseordernumber, o.subscription, 
                                o.serialid, o.basketno, o.biblioitemnumber, o.rrp, o.ecost,o.gst, o.budgetdate, o.sort1, o.sort2, 
                                b.bookfundid 
                         FROM aqorders o, aqorderbreakdown b
                         WHERE o.ordernumber=b.ordernumber",
   "10-aqorder_items.csv" => "SELECT ordernumber,barcode FROM aqorders_items LEFT JOIN items USING (itemnumber)",
   "11-authorities.mrc" => "SELECT marc FROM auth_header",
   "12-authorised_values.csv" => "SELECT category, authorised_value, lib, opaclib as lib_opac, imageurl FROM authorised_values",
   "12a-authorised_values.csv" => "SELECT category, authorised_value, lib, imageurl FROM authorised_values",
   "13-itemtypes.csv" => "SELECT itemtype, description, rentalcharge, notforloan, imageurl, summary FROM itemtypes",
   "14-frameworks.csv" => "SELECT * FROM biblio_framework",
   "15-marc_tag_structure.csv" => "SELECT * FROM marc_tag_structure",
   "16-marc_subfield_structure.csv" => "SELECT * FROM marc_subfield_structure",
   "17-borrower_attribute_types.csv" => "SELECT code, description, repeatable, unique_id, opac_display, password_allowed, 
                                                staff_searchable, authorised_value_category
                                         FROM borrower_attribute_types",
   "18-borrower_attributes.csv" => "SELECT cardnumber, code, attribute, borrowers.password
                                    FROM borrower_attributes
                                    JOIN borrowers USING (borrowernumber)",
   "19-borrowers.csv" => "SELECT cardnumber, surname, firstname, title, othernames, initials, streetnumber, streettype, address, 
                                 address2, city, zipcode, country, email, phone, mobile, fax, emailpro, phonepro, B_streetnumber,
                                 B_streettype, B_address, B_address2, B_city, B_zipcode, B_country, B_email, B_phone, dateofbirth, 
                                 branchcode, categorycode,dateenrolled,dateexpiry, gonenoaddress, lost, debarred, contactname, 
                                 contactfirstname, contacttitle, guarantorid, borrowernotes, relationship, ethnicity, ethnotes, 
                                 sex, password, flags, userid, opacnote, contactnote, sort1, sort2, altcontactfirstname, 
                                 altcontactsurname, altcontactaddress1, altcontactaddress2, altcontactzipcode, 
                                 altcontactcountry, altcontactphone, smsalertnumber 
                          FROM borrowers",
   "19a-borrowers.csv" => "SELECT cardnumber, surname, firstname, title, othernames, initials, streetnumber, streettype, address, 
                                  address2, city, zipcode, email, phone, mobile, fax, emailpro, phonepro, B_streetnumber,
                                  B_streettype, B_address, B_city, B_zipcode, B_email, B_phone, dateofbirth, 
                                  branchcode, categorycode,dateenrolled,dateexpiry, gonenoaddress, lost, 
                                  if(debarred=1,'2050-12-31','') AS debarred, contactname, 
                                  contactfirstname, contacttitle, guarantorid, borrowernotes, relationship, ethnicity, ethnotes, 
                                  sex, password, flags, userid, opacnote, contactnote, sort1, sort2, altcontactfirstname, 
                                  altcontactsurname, altcontactaddress1, altcontactaddress2, altcontactzipcode, 
                                  altcontactphone, smsalertnumber 
                           FROM borrowers",
   "20-categories.csv" => "SELECT categorycode, description, enrolmentperiod, upperagelimit, dateofbirthrequired, finetype, bulk,
                                  enrolmentfee, overduenoticerequired, issuelimit, reservefee, category_type
                           FROM categories",
   "21-branches.csv" => "SELECT branchcode, branchname, branchaddress1, branchaddress2, branchaddress3, branchzip, branchcity,
                                branchcountry, branchphone, branchfax, branchemail, branchurl, issuing, branchip, branchprinter,
                                branchnotes
                         FROM branches",
   "21a-branches.csv" => "SELECT branchcode, branchname, branchaddress1, branchaddress2, branchaddress3,
                                 branchphone, branchfax, branchemail, issuing, branchip, branchprinter
                          FROM branches",
   "21b-branches.csv" => "SELECT branchcode, branchname, branchaddress1, branchaddress2, branchaddress3, branchzip, branchcity,
                                branchcountry, branchphone, branchfax, branchemail, branchurl, issuing, branchip, branchprinter,
                                branchnotes, itembarcodeprefix,patronbarcodeprefix 
                         FROM branches",
   "22-issues.csv" => "SELECT cardnumber, barcode, date_due, issues.branchcode, issues.branchcode as issuingbranch, 
                              lastreneweddate, issues.renewals, issuedate
                       FROM issues
                       JOIN borrowers USING (borrowernumber)
                       JOIN items USING (itemnumber)",
   "22a-issues.csv" => "SELECT cardnumber, barcode, duedate as date_due, issues.branchcode, issues.branchcode as issuingbranch, 
                              lastreneweddate, issues.renewals, issuedate
                       FROM issues
                       JOIN borrowers USING (borrowernumber)
                       JOIN items USING (itemnumber)",
   "23-old_issues.csv" => "SELECT cardnumber, barcode, date_due, old_issues.branchcode, old_issues.branchcode as issuingbranch, 
                                  returndate, lastreneweddate, old_issues.renewals, issuedate
                           FROM old_issues
                           JOIN borrowers USING (borrowernumber)
                           JOIN items USING (itemnumber)",
   "23a-old_issues.csv" => "SELECT cardnumber, barcode, duedate as date_due, old_issues.branchcode, old_issues.branchcode as issuingbranch, 
                                  returndate, lastreneweddate, old_issues.renewals, issuedate
                           FROM old_issues
                           JOIN borrowers USING (borrowernumber)
                           JOIN items USING (itemnumber)",
   "24-letter.csv" => "SELECT module, code, name, title, content FROM letter",
   "24a-letter.csv" => "SELECT branchcode,module, code, name, title, content FROM letter",
   "25-messages.csv" => "SELECT cardnumber, message_id, messages.branchcode, message_type, message, message_date 
                         FROM messages
                         JOIN borrowers USING (borrowernumber)",
   "26-reserves.csv" => "SELECT cardnumber, reservedate, i2.barcode as bib_barcode,constrainttype, 
                                reserves.branchcode, notificationdate, reminderdate, cancellationdate, reservenotes, priority, 
                                found, items.barcode as barcode, waitingdate
                         FROM reserves 
                         LEFT JOIN borrowers using (borrowernumber)
                         LEFT JOIN items using (itemnumber)
                         LEFT JOIN items i2 on (reserves.biblionumber=i2.biblionumber)
                         GROUP BY cardnumber,reservedate,reserves.biblionumber",
   "26a-reserves.csv" => "SELECT cardnumber, reservedate, i2.barcode as bib_barcode, constrainttype, 
                                 reserves.branchcode, notificationdate, reminderdate, cancellationdate, reservenotes, priority,
                                 found, items.barcode as barcode, waitingdate, expirationdate
                         FROM reserves 
                         LEFT JOIN borrowers using (borrowernumber)
                         LEFT JOIN items using (itemnumber)
                         LEFT JOIN items i2 on (reserves.biblionumber=i2.biblionumber)
                         GROUP BY cardnumber,reservedate,reserves.biblionumber",
   "27-old_reserves.csv" => "SELECT cardnumber, reservedate, i2.barcode as bib_barcode, constrainttype,
                                    old_reserves.branchcode, 
                                    notificationdate, reminderdate, cancellationdate, reservenotes, priority, found,
                                    items.barcode as barcode, waitingdate
                             FROM old_reserves 
                             LEFT JOIN borrowers using (borrowernumber)
                             LEFT JOIN items using (itemnumber)
                             LEFT JOIN items i2 on (old_reserves.biblionumber=i2.biblionumber)
                             GROUP BY cardnumber,reservedate,old_reserves.biblionumber",
   "27a-old_reserves.csv" => "SELECT cardnumber, reservedate, i2.barcode as barcode, constrainttype,
                                     old_reserves.branchcode, 
                                     notificationdate, reminderdate, cancellationdate, reservenotes, priority, found,
                                     items.barcode as barcode, waitingdate, expirationdate
                              FROM old_reserves 
                              LEFT JOIN borrowers using (borrowernumber)
                              LEFT JOIN items using (itemnumber)
                              LEFT JOIN items i2 on (old_reserves.biblionumber=i2.biblionumber)
                              GROUP BY cardnumber,reservedate,old_reserves.biblionumber",
   "28-saved_sql.csv" => "SELECT id, cardnumber, date_created, last_modified, last_run, report_name, type, notes, savedsql 
                          FROM saved_sql
                          LEFT JOIN borrowers USING (borrowernumber)",
   "29-serials.csv" => "SELECT serialid, serial.biblionumber, subscriptionid, serialseq, status, planneddate, notes,
                               publisheddate, barcode, claimdate, routingnotes
                        FROM serial
                        LEFT JOIN items USING(itemnumber)",
   "30-subscription.csv" => "SELECT biblionumber, subscriptionid, librarian, startdate, aqbooksellerid, cost, weeklength,
                                    monthlength, numberlength, periodicity, dow, numberingmethod, notes, status, add1, 
                                    every1, whenmorethan1, setto1, lastvalue1, add2, every2, whenmorethan2, setto2, 
                                    lastvalue2, add3, every3, innerloop1, innerloop2, innerloop3, whenmorethan3, 
                                    setto3, lastvalue3, issuesatonce, firstacquidate, manualhistory, irregularity, letter,
                                    numberpattern, distributedto, internalnotes, callnumber, location, branchcode,
                                    hemisphere, lastbranch, serialsadditems, staffdisplaycount, opacdisplaycount, graceperiod
                            FROM subscription",
   "30a-subscription.csv" => "SELECT biblionumber, subscriptionid, librarian, startdate, aqbooksellerid, cost, weeklength,
                                     monthlength, numberlength, periodicity, dow, numberingmethod, notes, status, add1, 
                                     every1, whenmorethan1, setto1, lastvalue1, add2, every2, whenmorethan2, setto2, 
                                     lastvalue2, add3, every3, innerloop1, innerloop2, innerloop3, whenmorethan3, 
                                     setto3, lastvalue3, issuesatonce, firstacquidate, manualhistory, irregularity, letter,
                                     numberpattern, distributedto, internalnotes, callnumber, branchcode,
                                     hemisphere, lastbranch, serialsadditems, staffdisplaycount, opacdisplaycount
                             FROM subscription",
   "31-subscriptionhistory.csv" => "SELECT biblionumber,subscriptionid,histstartdate,enddate as histenddate, 
                                           missinglist, receivedlist, opacnote, librariannote
                                    FROM subscriptionhistory",
   "31a-subscriptionhistory.csv" => "SELECT biblionumber,subscriptionid,histstartdate,enddate as histenddate, 
                                            missinglist, recievedlist AS receivedlist, opacnote, librariannote
                                     FROM subscriptionhistory",
   "32-cities.csv" => "SELECT cityid, city_name, city_zipcode FROM cities",
   "33-currency.csv" => "SELECT currency, symbol, rate FROM currency",
   "34-repeat_holidays.csv" => "SELECT id, branchcode, weekday, day, month, title, description FROM repeatable_holidays",
   "35-special_holidays.csv" => "SELECT id, branchcode, day, month, year, isexception, title, description FROM special_holidays",
   "36-suggestions.csv" => "SELECT suggestionid, b.cardnumber as suggestedby_cardnumber, b2.cardnumber as managedby_cardnumber,
                                   status, note, author, suggestions.title, copyrightdate, publishercode, volumedesc,
                                   publicationyear, place, isbn, mailoverseeing, biblionumber, reason
                            FROM suggestions
                            LEFT JOIN borrowers b ON (suggestions.suggestedby=b.borrowernumber)
                            LEFT JOIN borrowers b2 ON (suggestions.managedby=b2.borrowernumber)",
   "37-sysprefs.csv" => "SELECT variable, value, options, explanation, type FROM systempreferences",
   "38-z_servers.csv" => "SELECT host, port, db, userid, password, name, id, checked, rank, syntax, icon, position, 
                                 type, encoding, description
                          FROM z3950servers",
   "39-class_sources.csv" => "SELECT * from class_sources",
   "40-def_branch_circ_rules.csv" => "SELECT branchcode, maxissueqty,holdallowed,'homebranch' AS returnbranch 
                                      FROM default_branch_circ_rules",
   "41-def_branch_item_rules.csv" => "SELECT itemtype, holdallowed, 'homebranch' AS returnbranch
                                      FROM default_branch_item_rules",
   "42-branch_item_rules.csv" => "SELECT branchcode,itemtype,holdallowed, 'homebranch' AS returnbranch
                                  FROM branch_item_rules",
   "43-def_circ_rules.csv" => "SELECT singleton,maxissueqty,holdallowed,'homebranch' AS returnbranch
                               FROM default_circ_rules",
   "44-branch_borrower_circ_rules.csv" => "SELECT branchcode,categorycode,maxissueqty FROM branch_borrower_circ_rules",
   "45-def_borrower_circ_rules.csv" => "SELECT categorycode, maxissueqty FROM default_borrower_circ_rules",
   "46-issuingrules.csv" => "SELECT if (circ_rules.branchcode IS NOT NULL, circ_rules.branchcode, '*') as branchcode,
                                    if (circ_rules.itemtype IS NOT NULL, circ_rules.itemtype, '*') as itemtype,
                                    if (circ_rules.categorycode IS NOT NULL, circ_rules.categorycode, '*') as categorycode,
                                    overdue_fine AS fine, fine_period AS chargeperiod,maxissueqty,issue_length as issuelength,
                                    issue_length_unit AS lengthunit, maxrenewals AS renewalsallowed, 
                                    if (categories.categorycode IS NOT NULL, categories.maxholds,
                                                                             default_branch_item_rules.holdallowed) AS reservesallowed
                             FROM circ_rules
                             JOIN circ_policies ON (circ_rules.circ_policies_id=circ_policies.id)
                             LEFT JOIN categories USING (categorycode)
                             LEFT JOIN default_branch_item_rules USING (itemtype)",
   "46a-issuingrules.csv" => "SELECT * from issuingrules",
   "46b-issuingrules.csv" => "select issuingrules.*,itemtypes.renewalsallowed,(select value from systempreferences where variable='maxreserves') as reservesallowed
                              from issuingrules left join itemtypes using (itemtype)",
   "47a-opacnews.csv" => "SELECT * from opac_news",
   "48-user_passwords.csv" => "SELECT cardnumber, password FROM borrowers",
   "49-message_transport_types.csv" => "SELECT * FROM message_transport_types",
   "50-message_attributes.csv" => "SELECT * from message_attributes",
   "51-message_transports.csv" => "SELECT * from message_transports",
   "52-guarantor_data.csv" => "select a.cardnumber,b.cardnumber from borrowers a join borrowers b on (b.borrowernumber=a.guarantorid)",
   "53-virtual_shelves.csv" => "select v.shelfnumber, v.shelfname, b.cardnumber, v.category, v.sortfield from virtualshelves v LEFT JOIN borrowers b on  b.borrowernumber=v.owner",
   "54-virtual_shelfcontents.csv" => "select * from virtualshelfcontents",
   "55-patronimage.csv" => "select * from patronimage",
   "56-courses.csv" => "SELECT course_id,department,course_number,section,course_name,
                               term,staff_note,public_note,students_count,timestamp
                        FROM courses",
   "57-course_items.csv" => "SELECT DISTINCTROW barcode as itembarcode, course_reserves.itemtype as itype, course_reserves.ccode, 
                                    course_reserves.branchcode as holdingbranch, course_reserves.location
                             FROM course_reserves
                             JOIN items USING (itemnumber)",
   "58-course_instructors.csv" => "SELECT course_id,cardnumber FROM instructor_course_link
                                   JOIN borrowers ON (instructor_course_link.instructor_borrowernumber=borrowers.borrowernumber)",
   "59-course_reserves.csv" => "SELECT course_id,barcode,staff_note,public_note,course_reserves.timestamp
                                FROM   course_reserves
                                JOIN   items USING (itemnumber)",
   "60-borrower_message_preferences.csv" => "SELECT borrower_message_preference_id,cardnumber,message_attribute_id,days_in_advance,
                                                    wants_digest 
                                             FROM   borrower_message_preferences
                                             LEFT JOIN borrowers using (borrowernumber)",
   "61-statistics.csv" => "SELECT datetime,branch,proccode,value,type,other,usercode,barcode,statistics.itemtype,cardnumber
                           FROM   statistics
                           LEFT JOIN borrowers USING (borrowernumber)
                           LEFT JOIN items USING (itemnumber)",
   "62-borrower_message_transport_preferences.csv" => "SELECT * from borrower_message_transport_preferences",
);

my $dbh = C4::Context->dbh();

QUERY:
foreach my $key (sort keys %queries) {
   say "Performing query for $key:";
   my $sth = $dbh->prepare($queries{$key});
   $sth->execute();
   if ($sth->err) {
      next QUERY;
   }
   open my $output_file,'>:utf8',$key;
   my $i = 0;
   if ($key =~ /\.mrc$/) {   #This file needs to be output in MARC!
MARC_RECORD:
      while (my @line = $sth->fetchrow_array()) {
         $i++;
         print "."    unless ($i % 10);
         print "\r$i" unless ($i % 100);
         my $marc;
         eval {$marc = MARC::Record->new_from_usmarc($line[0]); };
         if ($@){
            say "bogus record skipped";
            next MARC_RECORD;
         }
         print {$output_file} $marc->as_usmarc();
      }  #MARC_RECORD
      say "";
      say "$i records output.";
   }
   else {  #This file is a CSV!
      my @columns = @{$sth->{NAME}};
      foreach my $column (@columns){
         print {$output_file} "$column,";
      }
      print {$output_file} "\n";
RECORD:
      while (my @line = $sth->fetchrow_array()){
         $i++;
         print "."    unless ($i % 10);
         print "\r$i" unless ($i % 100);
         for my $k (0..scalar(@line)-1){
            if (!defined $line[$k]) {
               $line[$k] = $NULL_STRING;
            }
            $line[$k] =~ s/"/'/g;
            if ($line[$k] =~ /,/ || $line[$k] =~ /\n/ || $line[$k] =~ //){
               print {$output_file} '"'.$line[$k].'"';
            }
            else{
               print {$output_file} $line[$k];
            }
            print {$output_file} ',';
         }
         print {$output_file} "\n";
      }  #RECORD
      say "";
      say "$i records output.";
   }
}  #QUERY

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
