#!/m1/shared/bin/perl

use strict;
use warnings;
use DBI;
$|=1;

my $num_args = $#ARGV + 1;
if ($num_args != 3) {
  print "\nUsage: full_export.pl database_name username password\n";
  exit;
}

$ENV{ORACLE_SID} = "VGER";
$ENV{ORACLE_HOME} = "/oracle/app/oracle/product/11.2.0.3/db_1";
our $db_name = $ARGV[0];
our $username = $ARGV[1];
our $password = $ARGV[2];
our $sqllogin = "$ARGV[1]/$ARGV[2]".'@VGER';

my $dbh = DBI->connect('dbi:Oracle:', $sqllogin) || die "Could not connect: $DBI::errstr";


my $query = "SELECT patron_barcode.patron_barcode,patron.institution_id,circ_transactions.patron_id,
                    item_barcode.item_barcode,
                    circ_transactions.charge_date,circ_transactions.current_due_date,
                    circ_transactions.renewal_count
               FROM circ_transactions
               JOIN patron ON (circ_transactions.patron_id=patron.patron_id)
          LEFT JOIN patron_barcode ON (circ_transactions.patron_id=patron_barcode.patron_id)
          LEFT JOIN item_barcode ON (circ_transactions.item_id=item_barcode.item_id)
              WHERE patron_barcode.barcode_status = 1 AND patron_barcode.patron_barcode IS NOT NULL
                AND item_barcode.barcode_status = 1";

my %queries = (
   "01-bib_records.csv" => "SELECT BIB_DATA.RECORD_SEGMENT, BIB_DATA.BIB_ID, BIB_DATA.SEQNUM
                            FROM BIB_DATA
                            ORDER BY BIB_DATA.BIB_ID, BIB_DATA.SEQNUM",
   "02-items.csv"  => "SELECT bib_item.bib_id,bib_item.add_date,
                       item_vw.barcode,item_vw.perm_item_type_code,item_vw.perm_location_code,
                       item_vw.enumeration,item_vw.chronology,item_vw.historical_charges,item_vw.call_no,
                       item_vw.call_no_type,
                       item.price,item.copy_number,item.pieces,
                       item_note.item_note
                       FROM   item_vw
                       JOIN   item        ON (item_vw.item_id = item.item_id)
                       LEFT JOIN   item_note   ON (item_vw.item_id = item_note.item_id)
                       JOIN   bib_item    ON  (item_vw.item_id = bib_item.item_id)",
   "03-item_status_descriptions.csv" => "SELECT item_status_type.item_status_type, item_status_type.item_status_desc
                                         FROM item_status_type",
   "04-barcode_statuses.csv" => "SELECT item_vw.barcode,item_status.item_status FROM item_vw 
                                 JOIN item_status ON item_vw.item_id = item_status.item_id",
   "05-patron_addresses.csv" => "SELECT PATRON_ADDRESS.PATRON_ID, PATRON_ADDRESS.ADDRESS_TYPE, PATRON_ADDRESS.ADDRESS_LINE1, 
                                 PATRON_ADDRESS.ADDRESS_LINE2, PATRON_ADDRESS.ADDRESS_LINE3, PATRON_ADDRESS.ADDRESS_LINE4, 
                                 PATRON_ADDRESS.ADDRESS_LINE5, PATRON_ADDRESS.CITY, PATRON_ADDRESS.STATE_PROVINCE, 
                                 PATRON_ADDRESS.ZIP_POSTAL, PATRON_ADDRESS.COUNTRY
                                 FROM PATRON_ADDRESS
                                 ORDER BY PATRON_ADDRESS.PATRON_ID, PATRON_ADDRESS.ADDRESS_TYPE",
   "06-patron_groups.csv"    => "SELECT patron_barcode.patron_id, patron_barcode.patron_barcode, patron_barcode.barcode_status, 
                                 patron_barcode.patron_group_id FROM patron_barcode
                                 WHERE patron_barcode.patron_barcode IS NOT NULL",
   "06a-patron_group_names.csv" => "SELECT patron_group.patron_group_id,patron_group.patron_group_name FROM patron_group",
   "07-patron_names_dates.csv" => "SELECT PATRON.PATRON_ID, PATRON.LAST_NAME, PATRON.FIRST_NAME, PATRON.MIDDLE_NAME, PATRON.TITLE, 
                                   PATRON.CREATE_DATE, PATRON.EXPIRE_DATE, PATRON.INSTITUTION_ID
                                   FROM PATRON",
   "08-patron_groups_nulls.csv" => "SELECT patron_barcode.patron_id, patron_barcode.patron_barcode, patron_barcode.barcode_status,
                                    patron_barcode.patron_group_id FROM patron_barcode
                                    WHERE patron_barcode.patron_barcode IS NULL AND patron_barcode.barcode_status=1",
   "09-patron_notes.csv" => "SELECT patron_notes.patron_id,patron_notes.note FROM patron_notes 
                             order by patron_notes.patron_id,patron_notes.modify_date",
   "10-patron_phones.csv" => "SELECT patron_address.patron_id,
                              phone_type.phone_desc,
                              patron_phone.phone_number
                              FROM patron_phone
                              JOIN patron_address ON (patron_phone.address_id=patron_address.address_id)
                              JOIN phone_type ON (patron_phone.phone_type=phone_type.phone_type)",
   "11-patron_stat_codes.csv" => "SELECT patron_stats.patron_id,patron_stats.patron_stat_id,patron_stats.date_applied
                                  FROM patron_stats",
   "11a-patron_stat_desc.csv" => "SELECT patron_stat_code.patron_stat_id,patron_stat_code.patron_stat_desc
                                  FROM patron_stat_code",
   "12-current_circ.csv" => "SELECT patron_barcode.patron_barcode,patron.institution_id,circ_transactions.patron_id,
                             item_barcode.item_barcode,
                             circ_transactions.charge_date,circ_transactions.current_due_date,
                             circ_transactions.renewal_count
                             FROM circ_transactions
                             JOIN patron ON (circ_transactions.patron_id=patron.patron_id)
                             LEFT JOIN patron_barcode ON (circ_transactions.patron_id=patron_barcode.patron_id)
                             LEFT JOIN item_barcode ON (circ_transactions.item_id=item_barcode.item_id)
                             WHERE patron_barcode.barcode_status = 1 AND patron_barcode.patron_barcode IS NOT NULL
                             AND item_barcode.barcode_status = 1",
   "13-last_borrow_dates.csv" => "SELECT item_vw.barcode,max(charge_date)
                                  FROM circ_trans_archive
                                  JOIN item_vw ON (circ_trans_archive.item_id = item_vw.item_id)
                                  GROUP BY item_vw.barcode",
   "14-fines.csv" => "SELECT patron_barcode.patron_barcode,patron.institution_id,fine_fee.patron_id,
                      item_barcode.item_barcode,fine_fee.fine_fee_type,
                      fine_fee.create_date,fine_fee.fine_fee_balance,
                      fine_fee.fine_fee_note
                      FROM fine_fee
                      JOIN patron ON (fine_fee.patron_id=patron.patron_id)
                      LEFT JOIN patron_barcode ON (fine_fee.patron_id=patron_barcode.patron_id)
                      LEFT JOIN item_barcode ON (fine_fee.item_id=item_barcode.item_id)
                      WHERE patron_barcode.barcode_status = 1 and patron_barcode.patron_barcode is not null
                      AND item_barcode.barcode_status = 1
                      AND fine_fee.fine_fee_balance != 0",
   "15-OPAC_book_lists.csv" => "SELECT saved_records_results.patron_id,saved_records_results.bib_id 
                                FROM saved_records_results",
   "16-authorities.csv" => "SELECT AUTH_DATA.AUTH_ID, AUTH_DATA.RECORD_SEGMENT, AUTH_DATA.SEQNUM
                            FROM AUTH_DATA
                            ORDER BY AUTH_DATA.AUTH_ID, AUTH_DATA.SEQNUM",
   "17-fine_types.csv" => "SELECT fine_fee_type.fine_fee_type,fine_fee_type.fine_fee_desc FROM fine_fee_type",
   "18-item_stats.csv" => "SELECT item_stats.item_id,item_stat_code.item_stat_code
                           FROM item_stats JOIN item_stat_code ON (item_stats.item_stat_id = item_stat_code.item_stat_id)",
   "19-ser_component.csv" => "SELECT * FROM component",
   "20-ser_subsc.csv" => "SELECT * FROM subscription",
   "21-ser_issues.csv" => "SELECT * FROM serial_issues",
   "22-ser_claim.csv" => "SELECT * FROM serial_claim",
   "23-ser_vendor.csv" => "SELECT * FROM vendor",
   "24-ser_vendaddr.csv" => "SELECT * FROM vendor_address",
   "25-ser_vendnote.csv" => "SELECT * FROM vendor_note",
   "26-ser_vendphone.csv" => "SELECT * FROM vendor_phone",
   "27-ser_vw.csv" => "SELECT * from serials_vw",
   "28-ser_mfhd.csv" => "SELECT mfhd_data.mfhd_id, mfhd_data.seqnum, mfhd_data.record_segment
                         FROM mfhd_data 
                         LEFT JOIN serials_vw ON (mfhd_data.mfhd_id = serials_vw.mfhd_id) 
                         WHERE serials_vw.mfhd_id IS NOT NULL",
   "29-requests.csv" => "SELECT HOLD_RECALL.BIB_ID, HOLD_RECALL_ITEMS.ITEM_ID, HOLD_RECALL.REQUEST_LEVEL, 
                         HOLD_RECALL_ITEMS.QUEUE_POSITION, HOLD_RECALL_STATUS.HR_STATUS_DESC, LOCATION.LOCATION_CODE, 
                         HOLD_RECALL.CREATE_DATE, HOLD_RECALL.EXPIRE_DATE, HOLD_RECALL.PATRON_ID, 
                         PATRON_BARCODE.PATRON_BARCODE, ITEM_BARCODE.ITEM_BARCODE
                         FROM HOLD_RECALL
                         JOIN HOLD_RECALL_ITEMS ON (HOLD_RECALL_ITEMS.HOLD_RECALL_ID = HOLD_RECALL.HOLD_RECALL_ID)
                         JOIN HOLD_RECALL_STATUS ON (HOLD_RECALL_STATUS.HR_STATUS_TYPE = HOLD_RECALL_ITEMS.HOLD_RECALL_STATUS)
                         JOIN PATRON_BARCODE ON (PATRON_BARCODE.PATRON_ID = HOLD_RECALL.PATRON_ID)
                         JOIN LOCATION ON (LOCATION.LOCATION_ID = HOLD_RECALL.PICKUP_LOCATION)
                         JOIN ITEM_BARCODE ON (HOLD_RECALL_ITEMS.ITEM_ID = ITEM_BARCODE.ITEM_ID)
                         ORDER BY HOLD_RECALL_ITEMS.ITEM_ID, HOLD_RECALL_ITEMS.QUEUE_POSITION",
   "29a-locations.csv" => "SELECT location.location_id,location.location_code,location.location_name FROM location"
              );


foreach my $key (keys %queries) {
   my $filename = $key ;
   my $query    = $queries{$key};

   my $sth=$dbh->prepare($query) || die $dbh->errstr;
   $sth->execute() || die $dbh->errstr;

   my $i=0;
   open my $out,">",$filename || die "Can't open the output!";

   while (my @line = $sth->fetchrow_array()){
      $i++;
      print "."    unless ($i % 10);
      print "\r$i" unless ($i % 100);
      for my $k (0..scalar(@line)-1){
         if ($line[$k]){
            $line[$k] =~ s/"/'/g;
            if ($line[$k] =~ /,/){
               print {$out} '"'.$line[$k].'"';
            }
            else{
               print {$out} $line[$k];
            }
         }
         print {$out} ',';
      }
      print {$out} "\n";
   }   

   close $out;
   print "\n\n$i records exported\n";
}

exit;
