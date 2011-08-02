#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
# TODO: Borrower search history
# TODO: Serials
# TODO: Authorites
# TODO: Tags
# TODO: Suggestions
# TODO: Acquisitions
# TODO: Statistics
# TODO: Action Logs

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Members;

$|=1;
my $debug=0;

no warnings 'uninitialized';

my $infile_name = "";
my $branch = "";
my $branch_map_name = "";
my %branch_map;
my $shelfloc_map_name = "";
my %shelfloc_map;
my $itype_map_name = "";
my %itype_map;
my $collcode_map_name = "";
my %collcode_map;
my $patron_map_name = "";
my %patron_map;
my $patron_code_map_name = "";
my %patron_code_map;
my $tag_itypes_str = "";
my %tag_itypes;
my $frames_to_dump = "";
my $skip_biblio = 0;

GetOptions(
    'branch=s'          => \$branch,
    'branch_map=s'      => \$branch_map_name,
    'shelfloc_map=s'    => \$shelfloc_map_name,
    'itype_map=s'       => \$itype_map_name,
    'collcode_map=s'    => \$collcode_map_name,
    'patron_map=s'      => \$patron_map_name,
    'patron_code_map=s' => \$patron_code_map_name,
    'tag_itypes=s'      => \$tag_itypes_str,
    'frameworks=s'      => \$frames_to_dump,
    'skip_biblio'       => \$skip_biblio,
    'debug'             => \$debug,
);

if (($branch eq '')){
  print "Something's missing.\n";
  exit;
}

if ($branch_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$branch_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($shelfloc_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$shelfloc_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $shelfloc_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($itype_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$itype_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $itype_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($collcode_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$collcode_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $collcode_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($patron_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$patron_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $patron_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($patron_code_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$patron_code_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $patron_code_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($tag_itypes_str){
   my @tags = split(/,/,$tag_itypes_str);
   foreach my $tag (@tags){
      $tag_itypes{$tag} = 1;
   }
}

my $dbh = C4::Context->dbh();

# 
# BORROWER INFORMATION
#

print "Dumping borrower records:\n";
open my $out,">borrowers_".$branch.".csv";
my $sth = $dbh->prepare("SELECT * FROM borrowers WHERE branchcode='$branch'");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT * FROM borrowers");
}
my $sth2 = $dbh->prepare("SELECT code,attribute FROM borrower_attributes WHERE borrowernumber = ?");
$sth->execute();
my $i=0;
my %patron_categories;
my %patron_branches;
my @borrower_fields = qw /cardnumber surname firstname title othernames initials streetnumber streettype address address2 city  
                          zipcode country email phone mobile fax emailpro phonepro B_streetnumber B_streettype B_address 
                          B_address2 B_city B_zipcode B_country B_email B_phone dateofbirth branchcode categorycode dateenrolled 
                          dateexpiry gonenoaddress lost debarred contactname contactfirstname contacttitle guarantorid 
                          borrowernotes relationship ethnicity ethnotes sex password flags userid opacnote contactnote sort1 
                          sort2 altcontactfirstname altcontactsurname altcontactaddress1 altcontactaddress2 altcontactaddress3 
                          altcontactzipcode altcontactcountry altcontactphone smsalertnumber/;

for (my $counter=0;$counter<scalar(@borrower_fields);$counter++){
   print $out $borrower_fields[$counter].',';
}
print $out "patron_attributes\n";

while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $addedcode="";
   $row->{'guarantorid'} = '';
   $row->{'password'} = '';
   if ($row->{'borrowernotes'}){
      $row->{'borrowernotes'} =~ s/\n/--/g;
   }
   if ($row->{'opacnote'}){
      $row->{'opacnote'} =~ s/\n/--/g;
   }
   if (exists $patron_code_map{$row->{'categorycode'}}){
      $addedcode = $patron_code_map{$row->{'categorycode'}};
   }
   if (exists $patron_map{$row->{'categorycode'}}){
      $row->{'categorycode'} =  $patron_map{$row->{'categorycode'}};
   }
   $patron_categories{$row->{'categorycode'}}++;
   if (exists $branch_map{$row->{'branchcode'}}){
      $row->{'branchcode'} =  $branch_map{$row->{'branchcode'}};
   }
   $patron_branches{$row->{'branchcode'}}++;
   for (my $counter=0;$counter<scalar(@borrower_fields);$counter++){
      if ($row->{$borrower_fields[$counter]}){
         $row->{$borrower_fields[$counter]} =~ s/\"/'/g;
         if ($row->{$borrower_fields[$counter]} =~ /,/){
            print $out '"'.$row->{$borrower_fields[$counter]}.'"';
         }
         else{
            print $out $row->{$borrower_fields[$counter]};
         }
      }
      print $out ',';
   }
   $sth2->execute($row->{'borrowernumber'});
   while (my $row2 = $sth2->fetchrow_hashref()) {
       print $out ",$row2->{'code'}:$row2->{'attribute'}";
   }
   if ($addedcode){
       print $out ",$addedcode";
   }
   print $out "\n";
}
close $out;
print "\n$i records written.\n";
open $out,">patron_codes.sql";
print $out "# Branches \n";
foreach my $kee (sort keys %patron_branches){
   print $out "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','NEW--$kee');\n";
}
print $out "# Patron Categories\n";
foreach my $kee (sort keys %patron_categories){
   print $out "INSERT INTO categories (categorycode,description) VALUES ('$kee','NEW--$kee');\n";
}
close $out;
print "\nPATRON BRANCHES:\n";
foreach my $kee (sort keys %patron_branches){
   print $kee.":   ".$patron_branches{$kee}."\n";
}
print "\nPATRON CATEGORIES:\n";
foreach my $kee (sort keys %patron_categories){
   print $kee.":   ".$patron_categories{$kee}."\n";
}

print "Dumping guarantor records:\n";
open $out,">guarantors_".$branch.".csv";
$sth = $dbh->prepare("SELECT a.cardnumber, b.cardnumber FROM borrowers as a, borrowers as b 
                      WHERE a.guarantorid = b.borrowernumber AND a.branchcode='$branch'");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT a.cardnumber, b.cardnumber FROM borrowers as a, borrowers as b WHERE a.guarantorid = b.borrowernumber");
}
$sth->execute();
$i=0;
print $out "'guarantee cardnumber','guarantor cardnumber'\n";
while (my @row = $sth->fetchrow_array()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out join (',',@row),"\n";
}
close $out;
print "\n$i records written.\n";

print "Dumping password records:\n";
open $out,">passwords_".$branch.".csv";
$sth = $dbh->prepare("SELECT cardnumber,password FROM borrowers WHERE password IS NOT NULL AND password != '' AND branchcode='$branch'");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT cardnumber,password FROM borrowers WHERE password IS NOT NULL AND password != ''");
}
$sth->execute();
$i=0;
print $out "cardnumber,'password hash'\n";
while (my @row = $sth->fetchrow_array()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out join (',',@row),"\n";
}
close $out;
print "\n$i records written.\n";

print "Dumping borrower message preferences:\n";
open $out,">message_prefs_".$branch.".csv";
$sth = $dbh->prepare("SELECT cardnumber,message_attribute_id,days_in_advance,wants_digest
                      FROM borrower_message_preferences
                      JOIN borrowers ON (borrower_message_preferences.borrowernumber=borrowers.borrowernumber)");
$sth->execute();
$i=0;
print $out "cardnumber,message_attribute_id,days_in_advance,wants_digest\n";
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out "$row->{'cardnumber'},$row->{'message_attribute_id'},";
   if ($row->{'days_in_advance'}){
      print $out ",$row->{'days_in_advance'}";
   }
   print $out ",".$row->{'wants_digest'}."\n";
}
close $out;
print "\n$i records written\n";

print "Dumping messages:\n";
open $out,">messages_".$branch.".csv";
$sth = $dbh->prepare("SELECT cardnumber,messages.branchcode,message_type,message_date,message
                      FROM messages
                      JOIN borrowers USING (borrowernumber)");
$sth->execute();
$i=0;
print $out "cardnumber,branchcode,message_type,message_date,message\n";
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out "$row->{'cardnumber'},$row->{'branchcode'},$row->{'message_type'},$row->{'message_date'},";
   $row->{'message'} =~ s/\"/'/g;
   print $out '"'.$row->{'message'}.'"';
   print $out "\n";
}
close $out;
print "\n$i records written\n";


# 
# HISTORICAL DATA SECTION
#
print "Dumping old issues:\n";
open $out,">old_issues_".$branch.".csv";
$sth = $dbh->prepare("SELECT borrowers.cardnumber, items.barcode, 
                      date_due,old_issues.branchcode,issuingbranch,returndate,lastreneweddate,old_issues.return,old_issues.renewals,
                      old_issues.timestamp,issuedate
                      FROM old_issues, items, borrowers
                      WHERE old_issues.itemnumber = items.itemnumber AND old_issues.borrowernumber = borrowers.borrowernumber
                      AND old_issues.branchcode='$branch'");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT borrowers.cardnumber, items.barcode, 
                         date_due,old_issues.branchcode,issuingbranch,returndate,lastreneweddate,old_issues.return,old_issues.renewals,
                         old_issues.timestamp,issuedate
                         FROM old_issues, items, borrowers
                         WHERE old_issues.itemnumber = items.itemnumber AND old_issues.borrowernumber = borrowers.borrowernumber");
}
$sth->execute();
$i=0;
print $out "borrowers.cardnumber,items.barcode,date_due,branchcode,issuingbranch,returndate,lastreneweddate,";
print $out "return,renewals,timestamp,issuedate,\n";
while (my @row = $sth->fetchrow_array()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   for (my $count=0;$count<scalar(@row);$count++){
      if ($row[$count]){
         print $out $row[$count];
      }
      print $out ",";
   }
   print $out "\n";
}
close $out;
print "\n$i records written.\n";

print "Dumping old holds:\n";
open $out,">old_holds_".$branch.".csv";
$sth = $dbh->prepare("SELECT * from old_reserves WHERE branchcode='$branch'");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT * from old_reserves");
}
$sth->execute();
$i=0;
my @hold_fields = qw /reservedate constrainttype branchcode notificationdate reminderdate cancellationdate reservenotes 
                      priority found timestamp waitingdate expirationdate lowestPriority/;
print $out "borrowerbarcode,bibliobarcode,itembarcode,";
for (my $count=0;$count<scalar(@hold_fields);$count++){
   print $out $hold_fields[$count].",";
}
print $out "\n";

while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $borrowerbarcode = _get_borrower_cardnumber($row->{'borrowernumber'});
   my $itembarcode = GetBarcodeFromItemnumber($row->{'itemnumber'});
   my $bibliobarcode = _get_barcode_from_biblionumber($row->{'biblionumber'});
   if ($borrowerbarcode) {
      print $out $borrowerbarcode;
   }
   print $out ",";
   if ($bibliobarcode) {
      print $out $bibliobarcode;
   }
   print $out ",";
   if ($itembarcode) {
      print $out $itembarcode;
   }
   print $out ",";
   if ($row->{'reservenotes'}){
      $row->{'reservenotes'} =~ s/\"/'/;
      $row->{'reservenotes'} =~ s/\n/--/;
   }
   for (my $count=0;$count<scalar(@hold_fields);$count++){
      if ($row->{$hold_fields[$count]}){
         if ($row->{$hold_fields[$count]} =~ /,/){
            print $out '"'.$row->{$hold_fields[$count]}.'"';
         }
         else{
            print $out $row->{$hold_fields[$count]};
         }
      }
      print $out ",";
   }
   print $out "\n";
}
close $out;
print "\n$i records written.\n";

#
# TRANSACTIONS SECTION
#
print "Dumping current issues:\n";
open $out,">issues_".$branch.".csv";
$sth = $dbh->prepare("SELECT borrowers.cardnumber, items.barcode, date_due, issues.branchcode,
                             issuingbranch,returndate,lastreneweddate,issues.return,issues.renewals,issues.timestamp,issuedate
                             FROM issues, items, borrowers
                             WHERE issues.itemnumber = items.itemnumber AND issues.borrowernumber = borrowers.borrowernumber
                             AND (issues.branchcode='$branch' OR borrowers.branchcode='$branch' OR items.homebranch='$branch')");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT borrowers.cardnumber, items.barcode, date_due, issues.branchcode,
                             issuingbranch,returndate,lastreneweddate,issues.return,issues.renewals,issues.timestamp,issuedate
                             FROM issues, items, borrowers
                             WHERE issues.itemnumber = items.itemnumber AND issues.borrowernumber = borrowers.borrowernumber");
}
$sth->execute();
$i=0;
print $out "borrowers.cardnumber,items.barcode,date_due,branchcode,issuingbranch,returndate,lastreneweddate,";
print $out "return,renewals,timestamp,issuedate,\n";
while (my @row = $sth->fetchrow_array()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   for (my $count=0;$count<scalar(@row);$count++){
      if ($row[$count]){
         print $out $row[$count];
      }
      print $out ",";
   }
   print $out "\n";
}
close $out;
print "\n$i records written.\n";

print "Dumping current holds:\n";
open $out,">holds_".$branch.".csv";
$sth = $dbh->prepare("SELECT * from reserves WHERE branchcode='$branch'");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT * from reserves");
}
$sth->execute();
$i=0;
print $out "borrowerbarcode,bibliobarcode,itembarcode,";
for (my $count=0;$count<scalar(@hold_fields);$count++){
   print $out $hold_fields[$count].",";
}
print $out "\n";

while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $borrowerbarcode = _get_borrower_cardnumber($row->{'borrowernumber'});
   my $itembarcode = GetBarcodeFromItemnumber($row->{'itemnumber'});
   my $bibliobarcode = _get_barcode_from_biblionumber($row->{'biblionumber'});
   if ($bibliobarcode && $borrowerbarcode){
   print $out "$borrowerbarcode,$bibliobarcode,";
   if ($itembarcode) {
      print $out $itembarcode;
   }
   print $out ",";
   if ($row->{'reservenotes'}){
      $row->{'reservenotes'} =~ s/\"/'/;
      $row->{'reservenotes'} =~ s/\n/--/;
   }
   for (my $count=0;$count<scalar(@hold_fields);$count++){
      if ($row->{$hold_fields[$count]}){
         if ($row->{$hold_fields[$count]} =~ /,/){
            print $out '"'.$row->{$hold_fields[$count]}.'"';
         }
         else{
            print $out $row->{$hold_fields[$count]};
         }
      }
      print $out ",";
   }
   print $out "\n";
   }
}
close $out;
print "\n$i records written.\n";

print "Dumping account lines:\n";
open $out,">utf8:","accountlines_".$branch.".csv";
$sth = $dbh->prepare("SELECT * FROM accountlines");
$sth->execute();
$i=0;
my @acc_fields = qw /date amount description dispute accounttype amountoutstanding lastincrement timestamp notify_id notify_level/;

print $out "borrowerbarcode,itembarcode,";
for (my $count=0;$count<scalar(@acc_fields);$count++){
   print $out $acc_fields[$count].",";
}
print $out "\n";

while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $borrowerbarcode = _get_borrower_cardnumber($row->{'borrowernumber'});
   my $itembarcode = GetBarcodeFromItemnumber($row->{'itemnumber'});
   print $out "$borrowerbarcode,";
   if ($itembarcode) {
      print $out $itembarcode;
   }
   print $out ",";
   if ($row->{'description'}){
      $row->{'description'} =~ s/\"/'/;
      $row->{'description'} =~ s/^M\n/--/;
   }
   for (my $count=0;$count<scalar(@acc_fields);$count++){
      if ($row->{$acc_fields[$count]}){
         if ($row->{$acc_fields[$count]} =~ /,/){
            print $out '"'.$row->{$acc_fields[$count]}.'"';
         }
         else{
            print $out $row->{$acc_fields[$count]};
         }
      }
      print $out ",";
   }
   print $out "\n";
}
close $out;
print "\n$i records written.\n";

print "Dumping virtual shelves:\n";
open $out,">vshelves_".$branch.".csv";
$sth = $dbh->prepare("SELECT shelfnumber,shelfname,cardnumber,category,sortfield,lastmodified FROM virtualshelves 
                      JOIN borrowers ON (owner=borrowernumber) WHERE branchcode='$branch'");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT shelfnumber,shelfname,cardnumber,category,sortfield,lastmodified FROM virtualshelves 
                         JOIN borrowers ON (owner=borrowernumber)");
}
$sth->execute();
$i=0;
print $out "cardnumber,shelfnumber,category,lastmodified,shelfname,sortfield\n";
while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $row->{'shelfname'} =~ s/\"/'/g;
   print $out "$row->{'cardnumber'},$row->{'shelfnumber'},$row->{'category'},$row->{'lastmodified'},$row->{'shelfname'},";
   if ($row->{'sortfield'}){
      print $out $row->{'sortfield'};
   }
   print $out "\n";
}
close $out;
print "\n$i shelf records written.\n";
open $out,">vshelf_cont_".$branch.".csv";
$sth = $dbh->prepare("SELECT * from virtualshelfcontents");
$sth->execute();
$i=0;
print $out "bibliobarcode,shelfnumber,flags,dateadded\n";
while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $bibliobarcode = _get_barcode_from_biblionumber($row->{'biblionumber'});
   if ($bibliobarcode){
      print $out "$bibliobarcode,$row->{'shelfnumber'},$row->{'flags'},$row->{'dateadded'}\n";
   }
}
close $out;
print "\n$i shelf content records written.\n";

#
# ADMINISTRATION SECTION
#
print "Dumping circulation rules:\n";
open $out,">circrules_".$branch.".csv";
$sth = $dbh->prepare("SELECT * FROM issuingrules WHERE branchcode = '$branch' OR branchcode = '*'");
if ($branch eq "ALL"){
   $sth = $dbh->prepare("SELECT * FROM issuingrules");
}
$sth->execute();
$i=0;
print $out "categorycode,itemtype,restrictedtype,rentaldiscount,reservecharge,fine,firstremind,chargeperiod,accountsent,chargename,maxissueqty,issuelength,branchcode\n";
while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($branch ne 'ALL'){
      $row->{'branchcode'} = $branch;
   }
   print $out "$row->{'categorycode'},$row->{'itemtype'},$row->{'restrictedtype'},$row->{'rentaldiscount'},$row->{'reservecharge'},";
   print $out "$row->{'fine'},$row->{'firstremind'},$row->{'chargeperiod'},$row->{'accountsent'},$row->{'chargename'},";
   print $out "$row->{'maxissueqty'},$row->{'issuelength'},$row->{'branchcode'}\n";
}
close $out;
print "\n$i circulation rules written.\n";

print "Dumping saved_sql reports:\n";
open $out,">saved_sql_".$branch.".csv";
$sth = $dbh->prepare("SELECT cardnumber,date_created,last_modified,last_run,type,report_name,notes,savedsql
                      FROM saved_sql
                      JOIN borrowers USING (borrowernumber)");
$sth->execute();
$i=0;
print $out "cardnumber,date_created,last_modified,last_run,type,report_name,notes,savedsql\n";
while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out "$row->{'cardnumber'},$row->{'date_created'},$row->{'last_modified'},$row->{'last_run'},$row->{'type'},";
   $row->{'report_name'} =~ s/\"/'/g;
   $row->{'notes'} =~ s/\"/'/g;
   $row->{'savedsql'} =~ s/\"/\\\"/g;
   print $out '"',$row->{'report_name'}.'",';
   print $out '"',$row->{'notes'}.'",';
   print $out '"',$row->{'savedsql'}.'"';
   print $out "\n";
}
close $out;
print "\n$i reports written.\n";

print "Dumping framework codes:\n";
open $out,">biblio_framework_".$branch.".csv";
$sth = $dbh->prepare("SELECT * FROM biblio_framework");
if ($frames_to_dump ne ""){
   my @frames = split(/,/,$frames_to_dump);
   foreach my $frame (@frames){
      $frame = "'$frame'";
   }
   $frames_to_dump = join (',',@frames);
   $sth= $dbh->prepare("SELECT * FROM biblio_framework WHERE frameworkcode IN ($frames_to_dump)");
}

$sth->execute();
$i=0;
print $out "frameworkcode,frameworktext\n";
while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out "$row->{'frameworkcode'},$row->{'frameworktext'}\n";

}
close $out;
print "\n$i framework codes written.\n";

print "Dumping marc_tag_structure:\n";
open $out,">marc_tag_structure_".$branch.".csv";
$sth = $dbh->prepare("SELECT * FROM marc_tag_structure");
if ($frames_to_dump ne ""){
   $sth= $dbh->prepare("SELECT * FROM marc_tag_structure WHERE frameworkcode IN ($frames_to_dump)");
}
$sth->execute();
$i=0;
print $out "tagfield,liblibrarian,libopac,repeatable,mandatory,authorised_value,frameworkcode\n";
while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out "$row->{'tagfield'},".'"'."$row->{'liblibrarian'}".'","'."$row->{'libopac'}".'"'.",$row->{'repeatable'},$row->{'mandatory'},";
   print $out "$row->{'authorised_value'},$row->{'frameworkcode'}\n";
}
close $out;
print "\n$i MARC tag definitions written.\n";

print "Dumping marc_subfield_structure:\n";
open $out,">marc_subfield_structure_".$branch.".csv";
$sth = $dbh->prepare("SELECT * FROM marc_subfield_structure");
if ($frames_to_dump ne ""){
   $sth= $dbh->prepare("SELECT * FROM marc_subfield_structure WHERE frameworkcode IN ($frames_to_dump)");
}
$sth->execute();
$i=0;
print $out "tagfield,tagsubfield,liblibrarian,libopac,repeatable,mandatory,kohafield,tab,authorised_value,authtypecode,value_builder,isurl,hidden,frameworkcode,seealso,link,defaultvalue\n";
while (my $row = $sth->fetchrow_hashref()) {
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out "$row->{'tagfield'},$row->{'tagsubfield'},".'"'."$row->{'liblibrarian'}".'","'."$row->{'libopac'}".'",';
   print $out "$row->{'repeatable'},$row->{'mandatory'},$row->{'kohafield'},$row->{'tab'},";
   print $out "$row->{'authorised_value'},$row->{'authtypecode'},$row->{'value_builder'},$row->{'isurl'},";
   print $out "$row->{'hidden'},$row->{'frameworkcode'},".'"'."$row->{'seealso'}".'"'.",$row->{'link'},";
   print $out "$row->{'defaultvalue'}\n";
}
close $out;
print "\n$i MARC subfield definitions written.\n";

#
#
#  BIBLIOGRAPHIC INFORMATION SECTION
#

exit if ($skip_biblio);

print "Dumping bibliographic records:\n";
open $out,">:utf8","biblios_".$branch.".mrc";
my $pre = $dbh->prepare("SELECT DISTINCT biblionumber FROM items WHERE homebranch='$branch'");
if ($branch eq "ALL"){
   $pre = $dbh->prepare("SELECT DISTINCT biblionumber FROM items");
}
$sth = $dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
$pre->execute();
$i=0;
my %permloc;
my %curloc;
my %shelfloc;
my %itype;
my %itype_942;
my %collcode;

while (my $prerow = $pre->fetchrow_hashref()){
   #$debug and last if ($i > 5000);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $sth->execute($prerow->{'biblionumber'});
   my $row = $sth->fetchrow_hashref();
   my $marc = MARC::Record::new_from_usmarc($row->{'marc'});
   my $tag_this_biblio=0;
   my $tag_branch="";
   foreach my $field ($marc->field("942")){
      if ($field->subfield('c')){
      if (exists $itype_map{$field->subfield('c')}){
         $field->update( c => $itype_map{$field->subfield('c')});
      }
      $itype_942{$field->subfield('c')}++;
      }
   }
TAG952:
   foreach my $field ($marc->field("952")){
      next TAG952 if !$field->subfield('a');
      if  (($field->subfield('a') ne $branch) && ($branch ne "ALL")){
         $debug and print $prerow->{'biblionumber'};
         $debug and print Dumper($field);
         $marc->delete_field($field);
         next TAG952;
      }
      if (exists $branch_map{$field->subfield('a')}){
         $field->update( a => $branch_map{$field->subfield('a')});
      }
      $permloc{$field->subfield('a')}++;
      if ($field->subfield('b')){
         if (exists $branch_map{$field->subfield('b')}){
            $field->update( b => $branch_map{$field->subfield('b')});
         }
      }
      else{
         $field->add_subfields( b => $field->subfield('a'));
      }
      $curloc{$field->subfield('b')}++;
      if ($field->subfield('c') && exists $shelfloc_map{$field->subfield('c')}){
         $field->update( c => $shelfloc_map{$field->subfield('c')});
      }
      $shelfloc{$field->subfield('c')}++ if ($field->subfield('c'));
      if (!$field->subfield('y')){
         $field->update( y => "UNKNOWN" );
      }
      if (exists $tag_itypes{$field->subfield('y')}){
         $tag_this_biblio=1;
         $tag_branch=$field->subfield('a');
      }
      if (exists $itype_map{$field->subfield('y')}){
         $field->update( y => $itype_map{$field->subfield('y')});
      }
      $itype{$field->subfield('y')}++;
      if ($field->subfield('8') && exists $collcode_map{$field->subfield('8')}){
         $field->update( 8 => $collcode_map{$field->subfield('8')});
      }
      $collcode{$field->subfield('8')}++ if ($field->subfield('8'));
   }
   if ($tag_this_biblio){
     my $field=$marc->field("245");
     $field->update( a => $field->subfield('a')." -- $tag_branch");
   }
   print $out $marc->as_usmarc();
}
close $out;
open $out,">biblio_codes.sql";
print $out "# Branches \n";
foreach my $kee (sort keys %permloc){
   print $out "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','NEW--$kee');\n";
}
foreach my $kee (sort keys %curloc){
   print $out "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','NEW--$kee');\n" if (!$permloc{$kee});
}
print $out "# Shelving Locations\n";
foreach my $kee (sort keys %shelfloc){
   print $out "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','NEW--$kee');\n";
}
print $out "# Item Types\n";
foreach my $kee (sort keys %itype){
   print $out "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','NEW--$kee');\n";
}
foreach my $kee (sort keys %itype_942){
   print $out "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','NEW--$kee');\n" if (!$itype{$kee});
}
print $out "# Collection Codes\n";
foreach my $kee (sort keys %collcode){
   print $out "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','NEW--$kee');\n";
}
print "\n$i records written.\n";

print "\nHOME BRANCHES:\n";
foreach my $kee (sort keys %permloc){
   print $kee.":   ".$permloc{$kee}."\n";
}
print "\nHOLDING BRANCHES:\n";
foreach my $kee (sort keys %curloc){
   print $kee.":   ".$curloc{$kee}."\n";
}
print "\nSHELVING LOCATIONS:\n";
foreach my $kee (sort keys %shelfloc){
   print $kee.":   ".$shelfloc{$kee}."\n";
}
print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itype){
   print $kee.":   ".$itype{$kee}."\n";
}
print "\nITEM TYPES (942):\n";
foreach my $kee (sort keys %itype_942){
   print $kee.":   ".$itype_942{$kee}."\n";
}
print "\nCOLLECTION CODES\n";
foreach my $kee (sort keys %collcode){
   print $kee.":   ".$collcode{$kee}."\n";
}
print "\n";

exit;

sub _get_borrower_cardnumber {
   my $borrowernumber = shift;
   my $rq = $dbh->prepare("SELECT cardnumber FROM borrowers WHERE borrowernumber = ?");
   $rq->execute($borrowernumber);
   my ($cardnumber) = $rq->fetchrow;
   return $cardnumber;
}

sub _get_barcode_from_biblionumber {
   my ($biblionumber) = @_;
   my $rq = $dbh->prepare("SELECT barcode FROM items WHERE biblionumber=? ORDER BY itemnumber DESC LIMIT 1");
   $rq->execute($biblionumber);
   my ($result) = $rq->fetchrow;
   return ($result);
}


