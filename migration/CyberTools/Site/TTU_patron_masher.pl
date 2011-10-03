#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
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
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $fixed_branch = "UNKNOWN";
my $mapfile_name = "";
my %patron_cat_map;
my %branch_map;
my %attr1_map;
my %attr2_map;
my %attr3_map;
my $drop_code_str = "";
my %drop_codes;
my $hard_expiry = "";

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$mapfile_name,
    'branch=s'      => \$fixed_branch,
    'drop_codes=s'  => \$drop_code_str,
    'hard_expiry=s' => \$hard_expiry,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
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
      $branch_map{$data[0]} = uc $data[1];
      $patron_cat_map{$data[0]} = uc $data[2];
      $attr1_map{$data[0]} = uc $data[3];
      $attr2_map{$data[0]} = uc $data[4];
      $attr3_map{$data[0]} = uc $data[5];
   }
   close $mapfile;
}

open my $infl,"<",$infile_name || die ('problem opening $infile_name');
my $dum = readline($infl);
my $i=0;
my $written=0;

my $csv_format = Text::CSV_XS->new();
$csv_format->column_names( qw(Name            CLASS           SSN            Title       Suffix
                              Name_Norm       Local_Address   Local_City     Local_State
                              Local_Zip_Code  Local_Telephone Home_Address   Home_City
                              Home_State      Home_Zip_Code   Home_Telephone Bar_Code
                              Validation_Date Expiration_Date Alert          Comment
                              VIP_Title       Name_Ext        Additional_ID  Advance_Due
                              Email_1         Email_2         Patron_Num) );

my %patron_categories;
my %patron_branches;

my @borrower_fields = qw /cardnumber          surname 
                          firstname           title 
                          othernames          initials 
                          streetnumber        streettype 
                          address             address2
                          city                state              zipcode 
                          country             email 
                          phone               mobile 
                          fax                 emailpro 
                          phonepro            B_streetnumber 
                          B_streettype        B_address 
                          B_address2          B_city             B_state
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

open my $out2,">:utf8","patron_number_barcodes.csv";

RECORD:
while (my $row=$csv_format->getline_hr($infl)){
   last RECORD if ($debug and $i>10);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\n$i: ";
   $debug and print Dumper($row);

   next RECORD if ($drop_codes{uc $row->{CLASS}});

   my %thisrow;
   my $addedcode = q{};

   ($thisrow{surname}, $thisrow{firstname}) = split (/\,/,$row->{Name},2);
   if (!$thisrow{firstname} && $row->{Name} =~ /\./){
      ($thisrow{surname}, $thisrow{firstname}) = split (/\./,$row->{Name},2);
   }
   if (!$thisrow{firstname}){
      ($thisrow{surname}, $thisrow{firstname}) = split (/\s/,$row->{Name},2);
   }
   $thisrow{surname} =~ s/^\s+//ix;
   $thisrow{surname} =~ s/\s+$//ix;
   $thisrow{firstname} =~ s/^\s+//ix;
   $thisrow{firstname} =~ s/\s+$//ix;
   $thisrow{surname} .= $row->{Suffix} ne q{} ? ' '.$row->{Suffix}  : q{};

   $thisrow{categorycode} = uc $row->{CLASS};
   if (!$thisrow{categorycode}){
      $thisrow{categorycode} = "UNKNOWN";
   }
   if ($patron_cat_map{$thisrow{categorycode}}){
      $thisrow{categorycode} = $patron_cat_map{$thisrow{categorycode}};
   }
   $thisrow{sort1}         = $row->{Patron_Num};
   $thisrow{title}         = $row->{Title};

   $thisrow{B_address}     = $row->{Local_Address};
   $thisrow{B_city}        = $row->{Local_City};
   $thisrow{B_state}       = $row->{Local_State};
   $thisrow{B_zipcode}     = $row->{Local_Zip_Code};
   $thisrow{B_phone}       = $row->{Local_Telephone};

   $thisrow{address}       = $row->{Home_Address};
   $thisrow{city}          = $row->{Home_City};
   $thisrow{state}         = $row->{Home_State};
   $thisrow{zipcode}       = $row->{Home_Zip_Code};
   $thisrow{phone}         = $row->{Home_Telephone};

   $thisrow{cardnumber}    = $row->{Bar_Code};

   $thisrow{dateenrolled}  = _process_date($row->{Validation_Date});
   $thisrow{dateexpiry}    = _process_date($row->{Expiration_Date}) || $hard_expiry;

   $thisrow{borrowernotes} = $row->{Comment};

   $thisrow{othername}     = $row->{VIP_Title};

   $thisrow{emailpro}      = $row->{Email_1};
   $thisrow{email}         = $row->{Email_2};


   if ($thisrow{cardnumber}){
       if ($row->{Additional_ID} ne q{}){
          foreach my $id (split(/\,/,$row->{Additional_ID})){
             if ($id =~ m/[PR]\d\d/){
                $addedcode .= ",RNUM:".$id;
             }
             else{
                $thisrow{userid} = $id;
             }
          }
       }
       $thisrow{password}      = substr $thisrow{cardnumber},-4;
   }


   if (exists $branch_map{$row->{CLASS}}){
      $thisrow{branchcode} = $branch_map{$row->{CLASS}};
   } 

   if (!$thisrow{branchcode}){
      $thisrow{branchcode}    = $fixed_branch;
   }
   
   if (exists $attr1_map{$row->{CLASS}}){
      $addedcode .= ",INFO:".$attr1_map{$row->{CLASS}};
   }

   if (exists $attr2_map{$row->{CLASS}}){
      $addedcode .= ",SCHL:".$attr2_map{$row->{CLASS}};
   }

   if (exists $attr3_map{$row->{CLASS}}){
      $addedcode .= ",STUDY:".$attr3_map{$row->{CLASS}};
   }

   $addedcode =~ s/^,//;

   $debug and print Dumper(%thisrow);
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
open my $sql,">patron_sql.sql";
foreach my $kee (sort keys %patron_branches){
    print $kee.":  ".$patron_branches{$kee}."\n";
    print $sql "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print "\nResults by categorycode:\n";
foreach my $kee (sort keys %patron_categories){
    print $kee.":  ".$patron_categories{$kee}."\n";
    print $sql "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}
close $sql;

exit;

sub _process_date {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq q{};
   $debug and print " DATE: $datein\n";
   
   my ($month,$day,$year) = split(/\//,$datein);
   #$datein =~ m/(\d+)\/(\d+)\/(\d+) /;

   #my ($month,$day,$year) =( $1,$2,$3 ); 
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}

