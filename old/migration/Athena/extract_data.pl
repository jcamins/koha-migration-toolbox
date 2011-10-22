#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use DBI;
use MARC::Charset;
use MARC::Record;
use MARC::Field;

$|=1;
my $debug=0;

my $db = "";
my $user = "";
my $pass = "";
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
my $skip_biblio = 0;

GetOptions(
    'database=s'        => \$db,
    'user=s'            => \$user,
    'pass=s'            => \$pass,
    'branch=s'          => \$branch,
    'branch_map=s'      => \$branch_map_name,
    'shelfloc_map=s'    => \$shelfloc_map_name,
    'itype_map=s'       => \$itype_map_name,
    'collcode_map=s'    => \$collcode_map_name,
    'patron_map=s'      => \$patron_map_name,
    'patron_code_map=s' => \$patron_code_map_name,
    'tag_itypes=s'      => \$tag_itypes_str,
    'skip_biblio'       => \$skip_biblio,
    'debug'             => \$debug,
);

if (($branch eq '') || ($db eq '')){
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

my $dbh = DBI->connect("dbi:mysql:$db:localhost:3306",$user,$pass);

# 
# BORROWER INFORMATION
#
print "Dumping borrower records:\n";
open my $out,">borrowers_".$branch.".csv";
my $sth = $dbh->prepare("SELECT athena_patrons.*,athena_patron_types.type_name FROM athena_patrons 
                         LEFT JOIN athena_patron_types ON (athena_patrons.patron_type_oid = athena_patron_types.patron_type_oid)");
$sth->execute();
my $i=0;
my %patron_categories;
my %patron_branches;
my %addedcodes;
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
   my %thisrow;
   $thisrow{cardnumber} = $row->{'patron_id'};
   $thisrow{surname} = $row->{'surname'};
   $thisrow{firstname} = $row->{'first_name'};
   if ($row->{'middle_name'}){
      $thisrow{firstname} .= $row->{'middle_name'};
   }
   $thisrow{address} = $row->{'address1'};
   $thisrow{address2} = $row->{'address2'};
   $thisrow{city} = $row->{'city'};
   if ($row->{'province_state'}){
      $thisrow{city} .=", ".$row->{'province_state'};
   }
   $thisrow{zipcode} = $row->{'postal_zip'};
   $thisrow{email} = $row->{'email'};
   $thisrow{phone} = $row->{'user_defined3'};
   $thisrow{phonepro} = $row->{'user_defined4'};
   $thisrow{mobile} = $row->{'user_defined2'};
   $thisrow{borrowernotes} = "";
   if ($row->{'user_defined1'}){
      $thisrow{borrowernotes} .= "Video Note: ".$row->{'user_defined1'}." -- ";
   }
   if ($row->{'user_defined5'}){
      $thisrow{borrowernotes} .= "Seasonal Address Note: ".$row->{'user_defined5'}." -- ";
   }
   if ($row->{'user_defined6'}){
      $thisrow{borrowernotes} .= "Parent 1 Note: ".$row->{'user_defined6'}." -- ";
   }
   if ($row->{'user_defined7'}){
      $thisrow{borrowernotes} .= "Parent 2 Note: ".$row->{'user_defined7'}." -- ";
   }
   $thisrow{borrowernotes} =~ s/ \-\- $//;
   $thisrow{dateenrolled} = substr($row->{'date_added'},0,10);
   $thisrow{dateexpiry} = substr($row->{'privileges_expire'},0,10);
   $thisrow{categorycode} = uc($row->{'type_name'});
   $thisrow{categorycode} =~ s/ /_/g;
   $thisrow{branchcode} = $branch;
   if (exists $patron_code_map{$thisrow{categorycode}}){
      $addedcode = $patron_code_map{$thisrow{categorycode}};
   }
   if (exists $patron_map{$thisrow{categorycode}}){
      $thisrow{categorycode} =  $patron_map{$thisrow{categorycode}};
   }
   $patron_categories{$thisrow{categorycode}}++;
   $patron_branches{$thisrow{branchcode}}++;
   for (my $counter=0;$counter<scalar(@borrower_fields);$counter++){
      if ($thisrow{$borrower_fields[$counter]}){
         $thisrow{$borrower_fields[$counter]} =~ s/\"/'/g;
         if ($thisrow{$borrower_fields[$counter]} =~ /,/){
            print $out '"'.$thisrow{$borrower_fields[$counter]}.'"';
         }
         else{
            print $out $thisrow{$borrower_fields[$counter]};
         }
      }
      print $out ',';
   }
   if ($addedcode){
       $addedcodes{$addedcode}++;
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
print "\nPATRON CODES:\n";
foreach my $kee (sort keys %addedcodes){
   print $kee.":   ".$addedcodes{$kee}."\n";
}
 
#
# TRANSACTIONS SECTION
#
print "Dumping current issues:\n";
open $out,">issues_".$branch.".csv";
$sth = $dbh->prepare("SELECT patron_id,copy_id,due_date,trans_date
                             FROM athena_checkouts
                             LEFT JOIN athena_patrons ON (athena_checkouts.patron_oid = athena_patrons.patron_oid)
                             LEFT JOIN athena_copies ON (athena_checkouts.copy_oid = athena_copies.copy_oid)");
$sth->execute();
$i=0;
print $out "borrowers.cardnumber,items.barcode,date_due,branchcode,issuedate\n";
while (my $row = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   print $out $row->{'patron_id'}.",".$row->{'copy_id'}.",".substr($row->{'due_date'},0,10).",".$branch.",".substr($row->{'trans_date'},0,10);
   print $out "\n";
}
close $out;
print "\n$i records written.\n";

print "Dumping current holds:\n";
open $out,">holds_".$branch.".csv";
$sth = $dbh->prepare("SELECT patron_id,athena_holds.title_oid,copy_id,hold_available_date,hold_position,trans_date FROM athena_holds
                       LEFT JOIN athena_patrons ON (athena_holds.patron_oid = athena_patrons.patron_oid)
                       LEFT JOIN athena_copies ON (athena_holds.copy_oid = athena_copies.copy_oid)");
my $sth2 = $dbh->prepare("SELECT copy_id FROM athena_copies WHERE title_oid = ? LIMIT 1");
my @hold_fields = qw /reservedate constrainttype branchcode notificationdate reminderdate cancellationdate reservenotes
                      priority found timestamp waitingdate expirationdate lowestPriority/;
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
   $sth2->execute($row->{'title_oid'});
   my $biblioitem = $sth2->fetchrow_hashref();
   my %thisrow;
   if ($row->{'hold_available_date'}){
      $thisrow{waitingdate} = substr($row->{'hold_available_date'},0,10);
      $thisrow{found} = "W";
   }
   $thisrow{reservedate} = substr($row->{'trans_date'},0,10);
   print $out $row->{'patron_id'}.",".$biblioitem->{'copy_id'}.",";
   print $out $row->{'copy_id'} if $row->{'copy_id'};
   print $out ",";
   for (my $count=0;$count<scalar(@hold_fields);$count++){
      if ($thisrow{$hold_fields[$count]}){
         if ($thisrow{$hold_fields[$count]} =~ /,/){
            print $out '"'.$thisrow{$hold_fields[$count]}.'"';
         }
         else{
            print $out $thisrow{$hold_fields[$count]};
         }
      }
      print $out ",";
   }
   print $out "\n";
}
close $out;
print "\n$i records written.\n";

print "Dumping account lines:\n";
open $out,">utf8:","accountlines_".$branch.".csv";
$sth = $dbh->prepare("SELECT patron_id,copy_id,amount_paid,fine_amount,athena_fines.date_edited FROM athena_fines
                       LEFT JOIN athena_patrons ON (athena_fines.patron_oid = athena_patrons.patron_oid)
                       LEFT JOIN athena_copies ON (athena_fines.copy_oid = athena_copies.copy_oid) order by fine_oid");
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
   my %thisrow;
   $thisrow{amount} = $row->{'fine_amount'}/100;
   $thisrow{lastincrement} = $row->{'fine_amount'}/100;
   $thisrow{amountoutstanding} = ($row->{'fine_amount'}-$row->{'amount_paid'})/100;
   $thisrow{date} = substr($row->{'date_edited'},0,10);
   $thisrow{accounttype} = "F";
   $thisrow{accounttype} = "M" if (!$row->{'copy_id'});
   
   print $out $row->{'patron_id'}.",";
   print $out $row->{'copy_id'} if $row->{'copy_id'};
   print $out ",";
   
   for (my $count=0;$count<scalar(@acc_fields);$count++){
      if ($thisrow{$acc_fields[$count]}){
         if ($thisrow{$acc_fields[$count]} =~ /,/){
            print $out '"'.$thisrow{$acc_fields[$count]}.'"';
         }
         else{
            print $out $thisrow{$acc_fields[$count]};
         }
      }
      print $out ",";
   }
   print $out "\n";
}
close $out;
print "\n$i records written.\n";

#
#  BIBLIOGRAPHIC INFORMATION SECTION
#

exit if ($skip_biblio);

print "Dumping bibliographic records:\n";
open $out,">:utf8","biblios_".$branch.".mrc";
my $pre = $dbh->prepare("SELECT * FROM athena_titles");
$sth = $dbh->prepare("SELECT athena_copies.*,type_name from athena_copies 
                      LEFT JOIN athena_copy_types on (athena_copies.copy_type_oid = athena_copy_types.copy_type_oid)
                      WHERE title_oid=?");
$pre->execute();
$i=0;
my %permloc;
my %curloc;
my %shelfloc;
my %itype;
my %itype_942;
my %collcode;
my %loststat;
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');

while (my $prerow = $pre->fetchrow_hashref()){
   $debug and last if ($i > 5000);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $marc;
   eval{ $marc = MARC::Record::new_from_usmarc($prerow->{'marc'});};
   if ($@){
      print "\n Error in biblio $prerow->{'title_oid'}\n";
      next;
   }
   my $keeper_itype="";
   $sth->execute($prerow->{'title_oid'});
   my $copycount=0;
   while (my $row = $sth->fetchrow_hashref()){
      $copycount++;
      my $barcode = $row->{'copy_id'};
      my $itemcall = $row->{'call_number'};
      my $lastseen = substr($row->{'date_edited'},0,10);
      my $acqdate = substr($row->{'date_acquired'},0,10);
      my $price = $row->{'price'} || 0;
      $price = $price/100;
      my $pubnote = $row->{'public_note'};
      my $privnote = $row->{'public_note'};
      my $itemlost = 0;
      $itemlost = 1 if ($row->{'status'} ==3);
      my $itemtype = uc($row->{'type_name'});
      my $branchcode = $branch;
      my $loc = "";
      my $coll = "";

      if (exists $shelfloc_map{$itemtype}){
         $loc=$shelfloc_map{$itemtype};
         $shelfloc{$loc}++;
      }
      if (exists $collcode_map{$itemtype}){
         $coll=$collcode_map{$itemtype};
         $collcode{$coll}++;
      }
      if (exists $itype_map{$itemtype}){
         $itemtype=$itype_map{$itemtype};
      }
      $itype{$itemtype}++;
      $keeper_itype = $itemtype;
      if (exists $branch_map{$branchcode}){
         $branchcode=$branch_map{$branchcode};
      }
      $permloc{$branchcode}++;
      $curloc{$branchcode}++;
      $loststat{$itemlost}++;
      my $field=MARC::Field->new(
         952,"","",
         a => $branchcode,
         b => $branchcode,
         d => $acqdate,
         g => $price,
         o => $itemcall,
         p => $barcode,
         s => $lastseen,
         t => $copycount,
         v => $price,
         y => $itemtype,
         1 => $itemlost,
         2 => "ddc");
      if ($privnote){
         $field->add_subfields( x => $privnote);
      }
      if ($pubnote){
         $field->add_subfields( z => $pubnote);
      }
      if ($loc){
         $field->add_subfields( c => $loc);
      }
      if ($coll){
         $field->add_subfields( 8 => $coll);
      }
      $marc->insert_grouped_field($field);
   }
   my $field=MARC::Field->new(
     942,"","",
     c => $keeper_itype);
   $marc->insert_grouped_field($field);
   $itype_942{$keeper_itype}++;

   eval{ print $out $marc->as_usmarc();};
   if ($@){
      print "\n Error in biblio $prerow->{'title_oid'}\n";
   }
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
print "\nSTATUSES\n";
foreach my $kee (sort keys %loststat){
   print $kee.":   ".$loststat{$kee}."\n";
}
print "\n";

exit;

