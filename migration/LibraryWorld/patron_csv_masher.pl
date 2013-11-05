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
my $fixed_branch = "";
my $mapfile_name = "";
my %patron_cat_map;
my $branch_map_name = "";
my %branch_map;
my $drop_code_str = "";
my %drop_codes;
my $hard_expiry = "";
my $city_map_name = "";
my %city_map;
my $state_map_name ="";
my %state_map;
my $sex_map_name = "";
my %sex_map;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$mapfile_name,
    'branch=s'      => \$fixed_branch,
    'branch_map=s'  => \$branch_map_name,
    'city_map=s'    => \$city_map_name,
    'state_map=s'   => \$state_map_name,
    'sex_map=s'     => \$sex_map_name,
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
      $patron_cat_map{$data[0]} = $data[1];
   }
   close $mapfile;
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

if ($city_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$city_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $city_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($state_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$state_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $state_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($sex_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$sex_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $sex_map{$data[0]} = $data[1];
   }
   close $mapfile;
}


open my $infl,"<",$infile_name || die ('problem opening $infile_name');
my $dum = readline($infl);
my $i=0;
my $written=0;

my $csv_format = Text::CSV_XS->new({ sep_char => "\t" });
$csv_format->column_names( "Bar Code",       "Name",           "First Name",   "Branch",   "Code",
                           "Type",           "Sup/Teacher",    "Organization", "Dept.",    "Address 1",
                           "Address2",       "City",           "State",        "Zip",      "Country",
                           "Phone",          "Email",          "Grade",        "Gender",   "Ethnicity",
                           "Birth Date",     "Grad. Date",     "Parent Info.", "Comments", "Custom Field 1",
                           "Custom Field 2", "Custom Field 3", "Custom Field 4");

my %patron_categories;
my %patron_cities;
my %patron_states;
my %patron_sexes;
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
   last RECORD if ($debug and $i>0);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\n$i: ";
   $debug and print Dumper($row);

   next RECORD if ($drop_codes{uc $row->{CLASS}});

  # print "$row->{Patron_Num},$row->{Bar_Code}\n";

   my %thisrow;
   my $addedcode;

   $thisrow{surname} = $row->{Name};
   $thisrow{firstname} = $row->{"First Name"};

   $thisrow{surname} =~ s/^\s+//ix;
   $thisrow{surname} =~ s/\s+$//ix;
   $thisrow{firstname} =~ s/^\s+//ix;
   $thisrow{firstname} =~ s/\s+$//ix;

   $thisrow{categorycode} = uc $row->{Type};
   if (!$thisrow{categorycode}){
      $thisrow{categorycode} = "UNKNOWN";
   }
   if ($patron_cat_map{$thisrow{categorycode}}){
      $thisrow{categorycode} = $patron_cat_map{$thisrow{categorycode}};
   }

   $thisrow{address}       = $row->{"Address 1"};
   $thisrow{address2}      = $row->{Address2};
   $thisrow{city}          = $row->{City};
   $thisrow{state}         = $row->{State};
   $thisrow{zipcode}       = $row->{Zip};
   $thisrow{phone}         = $row->{Phone};

   $thisrow{cardnumber}    = $row->{"Bar Code"};

   $thisrow{dateexpiry}    = $hard_expiry;

   $thisrow{borrowernotes} = $row->{"Parent Info."};
   $thisrow{borrowernotes} .= "--".$row->{Comments};
   $thisrow{borrowernotes} =~ s/^\-\-//;

   $thisrow{email}         = $row->{Email};
   $thisrow{sex}           = $row->{Gender};

   if ($row->{Branch} ne q{}){
      $addedcode="ALT_ID:".$row->{Branch};
   }
   if ($city_map{$thisrow{city}}){
      $thisrow{city} = $city_map{$thisrow{city}};
   }
   if ($state_map{$thisrow{state}}){
      $thisrow{state} = $state_map{$thisrow{state}};
   }
   if ($sex_map{$thisrow{sex}}){
      $thisrow{sex} = $sex_map{$thisrow{sex}};
   }

   if ($thisrow{cardnumber}){
       $thisrow{userid}        = $thisrow{cardnumber};
       $thisrow{password}      = substr $thisrow{cardnumber},-4;
   }


   if (!$thisrow{branchcode}){
      $thisrow{branchcode}    = $fixed_branch;
   }

   $debug and print Dumper(%thisrow);
   $patron_categories{$thisrow{categorycode}}++;
   $patron_branches{$thisrow{branchcode}}++;
   $patron_cities{$thisrow{city}}++ if $thisrow{city};
   $patron_states{$thisrow{state}}++ if $thisrow{state};
   $patron_sexes{$thisrow{sex}}++ if $thisrow{sex};
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
print "\nResults by city:\n";
foreach my $kee (sort keys %patron_cities){
    print $kee.":  ".$patron_cities{$kee}."\n";
}
print "\nResults by state:\n";
foreach my $kee (sort keys %patron_states){
    print $kee.":  ".$patron_states{$kee}."\n";
}
print "\nResults by sex:\n";
foreach my $kee (sort keys %patron_sexes){
    print $kee.":  ".$patron_sexes{$kee}."\n";
}

exit;

sub _process_date {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq q{};

   $datein =~ m/(\d+)\/(\d+)\/(\d+) /;

   my ($month,$day,$year) =( $1,$2,$3 ); 
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}

