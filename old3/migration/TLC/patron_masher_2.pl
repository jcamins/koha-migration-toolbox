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
use Encode;
use Getopt::Long;
use Text::CSV;
use Text::CSV::Simple;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $sqlfile_name = "";
my $fixed_branch = "";
my $mapfile_name = "";
my $addressfile = "";
my $attribfile = "";
my %patron_cat_map;
my $drop_code_str = "";
my %drop_codes;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$mapfile_name,
    'branch=s'      => \$fixed_branch,
    'address=s'     => \$addressfile,
    'attrib=s'      => \$attribfile,
    'drop_codes=s'  => \$drop_code_str,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($addressfile eq "") || ($attribfile eq "")){
  print "Something's missing.\n";
  exit;
}
if ($drop_code_str){
   foreach my $code (split(/,/,$drop_code_str)){
      $drop_codes{$code} = 1;
   }
}

if ($mapfile_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$mapfile_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $patron_cat_map{$data[0]} = $data[1];
   }
   close $mapfile;
}


open my $infl,"<$infile_name" || die ('problem opening $infile_name');
my $i=0;
my $written=0;

my $csv_format = Text::CSV::Simple->new();
$csv_format->field_map( qw(AGENCYNUMBER            BARCODE 
                              ALTERNATEID             ISSUEDDATE
                              ISSUINGBRANCH           EXPIRATIONDATE 
                              AGENCYTYPE              B
                              RESPONSIBLEAGENCYNUMBER PIN 
                              FIRSTNAME               MIDDLENAME
                              LASTNAME                NAMESUFFIX 
                              FORMATNAME              SALUTATION 
                              DOB                     G
                              AGENCYCOMMENT           EMAILADDRESS    LASTACTIVEDATE 
                              LASTACTIVEBRANCH        DATEEDIT 
                              DATEUPDATE              LASTAGENCYBARCODE
                              DATEBARCODECHANGED      TOTALCHECKOUTS
                              CHECIKOUTSTHISPERIOD    ITEMSLOST
                              ITEMSCLAIMEDRETURNED    ITEMSCLAIMEDNEVERCHECKEDOUT
                              FINESTOTALWAIVED        BOOKEDARRIVALSNEGLECTED 
                              P                       AGENCYCHECKOUTSTATS       
                              AGENCYFINESTATS         FORMATEMAILADDRESS
                              FRIEN                   OVERD   
                              FINAL                   ARRIV   
                              CANCE                   EXPIR
                              ACCOUNTBALANCE) );

my $addr_format = Text::CSV::Simple->new();
$addr_format->field_map( qw(AGENCYNUMBER    ADDRESSNUMBER    
                            LINE1               LINE2
                            LINE3               CITY
                            STATE               ZIP
                            PHONE1              PHONE2
                            CORRECTIONREQUESTED ADDRESSCOMMENT
                            ORGANIZATIONNUMBER  FORMATPHONE1
                            FORMATPHONE2) );

my %thisrow;
my $addedcode;
my %patron_categories;
my %patron_branches;

my @borrower_fields = qw /cardnumber          surname 
                          firstname           title 
                          othernames          initials 
                          streetnumber        streettype 
                          address             address2
                          city                zipcode 
                          country             email 
                          phone               mobile 
                          fax                 emailpro 
                          phonepro            B_streetnumber 
                          B_streettype        B_address 
                          B_address2          B_city 
                          B_zipcode           B_country 
                          B_email             B_phone 
                          dateofbirth         branchcode 
                          categorycode        dateenrolled 
                          dateexpiry          gonenoaddress 
                          lost                debarred 
                          contactname         contactfirstname 
                          contacttitle        guarantorid
                          borrowernotes       relationship 
                          ethnicity           ethnotes 
                          sex                 password 
                          flags               userid 
                          opacnote            contactnote        
                          sort1               sort2             
                          altcontactfirstname altcontactsurname  
                          altcontactaddress1  altcontactaddress2 
                          altcontactaddress3  altcontactzipcode 
                          altcontactcountry   altcontactphone
                          smsalertnumber/;

open my $out,">:utf8",$outfile_name;
for my $j (0..scalar(@borrower_fields)-1){
   print $out $borrower_fields[$j].',';
}
print $out "patron_attributes\n";

RECORD:
for my $row ($csv_format->read_file($infl)){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   next RECORD if ($drop_codes{$row->{AGENCYTYPE}});

   $thisrow{cardnumber}    = $row->{BARCODE};
   $thisrow{branchcode}    = $row->{ISSUINGBRANCH};
   $thisrow{categorycode}  = $row->{AGENCYTYPE};
   $thisrow{userid}        = $row->{BARCODE};
   $thisrow{password}      = $row->{PIN};
   $thisrow{firstname}     = $row->{FIRSTNAME};
   $thisrow{surname}       = $row->{LASTNAME};
   $thisrow{sex}           = $row->{G};
   $thisrow{borrowernotes} = $row->{AGENCYCOMMENT};
   $thisrow{email}         = $row->{EMAILADDRESS};
   
   $thisrow{dateenrolled} = _process_date($row->{ISSUEDDATE});
   $thisrow{dateexpiry}   = _process_date($row->{EXPIRATIONDATE});
   $thisrow{dateofbirth}  = _process_date($row->{DOB});

   $thisrow{firstname}   .= $row->{MIDDLENAME} ne q{}   ? ' '.$row->{MIDDLENAME}   : q{};
   $thisrow{surname}     .= $row->{NAMESUFFIX} ne q{}   ? ', '.$row->{NAMESUFFIX}  : q{};
   $thisrow{debarred}     = $row->{B} eq 'B'            ? 1                        : 0;   
   $addedcode             = $row->{ALTERNATEID} ne q{} ? 'DL:'.$row->{ALTERNATEID} : undef;

   if ($patron_cat_map{$row->{AGENCYTYPE}}){
      $thisrow{categorycode} = $patron_cat_map{$row->{AGENCYTYPE}};
   }

   if ($fixed_branch){
      $thisrow{'branchcode'} = $fixed_branch;
   }

   my @attrib_matches = qx{grep "^$row->{AGENCYNUMBER}," $attribfile};
   $debug and print scalar(@attrib_matches);
   foreach my $match (@attrib_matches){
      my $parser = Text::CSV->new();
      $parser->parse($match);
      my @row1= $parser->fields();
      if ($addedcode){
         $addedcode .= ',';
      }
      if ($row1[1] == 1){
         $addedcode .= 'INTERNET:'.$row1[2];
      }
      if ($row1[1] == 21){
         $addedcode .= 'ALTID:'.$row1[2]; 
      }
      if ($row1[1] == 27){
         $addedcode .= 'RESP:'.$row1[2];
      }
   }

   my @address_matches = qx{grep "^$row->{AGENCYNUMBER}," $addressfile};
   foreach my $match (@address_matches){
      my $parser = Text::CSV->new();
      $parser->parse($match);
      my @row1= $parser->fields();
      if ($row1[11] ne ""){
         if ($thisrow{borrowernotes} ne ""){
            $thisrow{borrowernotes} .= " -- ";
         }
         $thisrow{borrowernotes} .= $row1[11];
      }
      if ($row1[1] == 1){
         $thisrow{address} = $row1[2];
         $thisrow{address2} = $row1[3];
         $thisrow{city}     = $row1[5].', '.$row1[6];
         $thisrow{zipcode}  = $row1[7];
         $thisrow{phone}    = $row1[8];
         $thisrow{phonepro} = $row1[9];
      }
      else{
         $thisrow{B_address} = $row1[2];
         $thisrow{B_address2} = $row1[3];
         $thisrow{B_city}     = $row1[5].', '.$row1[6];
         $thisrow{B_zipcode}  = $row1[7];
         $thisrow{B_phone}    = $row1[8];
      }
   }
   $patron_categories{$thisrow{categorycode}}++;
   $patron_branches{$thisrow{branchcode}}++;
   for my $j (0..scalar(@borrower_fields)-1){
      if ($thisrow{$borrower_fields[$j]}){
         $thisrow{$borrower_fields[$j]} =~ s/\"/'/g;
         if ($thisrow{$borrower_fields[$j]} =~ /,/){
            print $out '"'.$thisrow{$borrower_fields[$j]}.'"';
         }
         else{
            print $out $thisrow{$borrower_fields[$j]};
         }
      }
      print $out ",";
   }
   if ($addedcode){
       print $out '"'."$addedcode".'"';
   }
   print $out "\n";
   $written++;
}

close $infl;
close $out;

print "\n\n$i lines read.\n$written borrowers written.\n";
print "\nResults by branchcode:\n";
foreach my $kee (sort keys %patron_branches){
    print $kee.":  ".$patron_branches{$kee}."\n";
}
open my $sql,">patron_sql.sql";
print "\nResults by categorycode:\n";
foreach my $kee (sort keys %patron_categories){
    print $kee.":  ".$patron_categories{$kee}."\n";
    print $sql "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}
close $sql;

exit;

sub _process_date {
   my $datein= shift;
   return undef if ($datein eq q{});
   $datein =~ m/(\d{2})-(\d{2})-(\d{4})/;
   my ($month,$day,$year) = ($1,$2,$3);
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
