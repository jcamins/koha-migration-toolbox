#!/m1/shared/bin/perl

use strict;
use warnings;
use DBI;
$|=1;

$ENV{ORACLE_SID} = "VGER";
$ENV{ORACLE_HOME} = "/oracle/app/oracle/product/11.2.0.3/db_1";
our $db_name = "gmcdb";
our $username = "gmcdb";
our $password = "Qgmcdb";
our $sqllogin = 'gmcdb/Qgmcdb@VGER';

my $dbh = DBI->connect('dbi:Oracle:', $sqllogin) || die "Could not connect: $DBI::errstr";
my $query = "SELECT bib_item.bib_id,bib_item.add_date,
                      item_vw.barcode,item_vw.perm_item_type_code,item_vw.perm_location_code,
                      item_vw.enumeration,item_vw.chronology,item_vw.historical_charges,item_vw.call_no,
                      item_vw.call_no_type,
                      item.price,item.copy_number,item.pieces,
                      item_note.item_note
               FROM   item_vw
               JOIN   item        ON (item_vw.item_id = item.item_id)
          LEFT JOIN   item_note   ON (item_vw.item_id = item_note.item_id)
               JOIN   bib_item   ON  (item_vw.item_id = bib_item.item_id)";

my $sth=$dbh->prepare($query) || die $dbh->errstr;
$sth->execute() || die $dbh->errstr;

my $i=0;
open my $out,">","item_data.csv" || die "Can't open the output!";

while (my @line = $sth->fetchrow_array()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   for my $k (0..scalar(@line)-1){
      if ($line[$k]){
         $line[$k] =~ s/"/'/g;
         if ($line[$k] =~ /,/){
            print $out '"'.$line[$k].'"';
         }
         else{
            print $out $line[$k];
         }
      }
      print $out ',';
   }
   print $out "\n";
}   

close $out;
print "\n\n$i items exported\n";
