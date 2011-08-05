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
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $fixed_branch = "";
my $mapfile_name = "";
my $addressfile = "";
my $phonefile = "";
my $statfile = "";
my $barcodefile = "";
my %patron_cat_map;
my $branch_map_name = "";
my %branch_map;
my $drop_code_str = "";
my %drop_codes;
my $use_inst_id = 0;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$mapfile_name,
    'branch=s'      => \$fixed_branch,
    'branch_map=s'  => \$branch_map_name,
    'address=s'     => \$addressfile,
    'phone=s'       => \$phonefile,
    'statfile=s'    => \$statfile,
    'barfile=s'     => \$barcodefile,
    'drop_codes=s'  => \$drop_code_str,
    'use_inst'      => \$use_inst_id,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '') || ($addressfile eq "") || ($phonefile eq "") || ($fixed_branch eq "")
     || ($barcodefile eq q{})){
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


open my $infl,"<",$infile_name || die ('problem opening $infile_name');
my $i=0;
my $written=0;

my $csv_format = Text::CSV_XS->new();
$csv_format->column_names( qw(PATRON_ID LASTNAME       
                              FIRSTNAME MIDDLENAME TITLE   
                              ISSUEDATE EXPIRATIONDATE INSTITUTION_ID ) );

my $addr_format = Text::CSV_XS->new();
$addr_format->column_names( qw(BARCODE ADDRESSTYPE
                            LINE1   LINE2
                            LINE3   LINE4
                            LINE5   CITY
                            STATE   ZIP
                            COUNTRY) );

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

my $no_barcode=0;

RECORD:
while (my $row=$csv_format->getline_hr($infl)){
   last RECORD if ($debug and $i>10);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\n$i: ";
   $debug and print Dumper($row);

   next RECORD if ($drop_codes{uc $row->{CATEGORY}});

   my %thisrow;
   my $addedcode;

   $thisrow{firstname}     = $row->{FIRSTNAME};
   $thisrow{surname}       = $row->{LASTNAME};
   $thisrow{title}         = $row->{TITLE};
   $thisrow{sort1}         = $row->{INSTITUTION_ID};
   
   $thisrow{dateenrolled} = _process_date($row->{ISSUEDATE},50);
   $thisrow{dateexpiry}   = _process_date($row->{EXPIRATIONDATE},50);

   $thisrow{firstname}   .= $row->{MIDDLENAME} ne q{}   ? ' '.$row->{MIDDLENAME}   : q{};

   $thisrow{cardnumber}   = ''; 
   if ($use_inst_id){
      $thisrow{cardnumber}   = $row->{INSTITUTION_ID};
   }

   my $matchpoint = $row->{PATRON_ID};


   my @bar_matches = qx{grep "^$matchpoint," $barcodefile};
BAR_MATCH:
   foreach my $match (@bar_matches){
      print $match if $matchpoint == 1827;
      my $parser = Text::CSV->new();
      $parser->parse($match);
      my @row1=$parser->fields();
      next BAR_MATCH if ($row1[2] != 1);
      if (!$use_inst_id){
         $thisrow{cardnumber}    = $row1[1];
      }
      $thisrow{categorycode}  = uc $row1[3];
   }
   
   if ($thisrow{cardnumber} eq q{}){
       $thisrow{cardnumber} = sprintf "TEMP%d",$matchpoint;
       $no_barcode++;
   }

   $thisrow{userid}        = $thisrow{cardnumber};
   $thisrow{password}      = substr $thisrow{cardnumber},-4;

   if (!$thisrow{categorycode}){
      $thisrow{categorycode} = "UNKNOWN";
   }
   if ($patron_cat_map{$thisrow{categorycode}}){
      $thisrow{categorycode} = $patron_cat_map{$thisrow{categorycode}};
   }

   my @address_matches = qx{grep "^$matchpoint,1," $addressfile};
   foreach my $match (@address_matches){
      $debug and print $match;
      my $parser = Text::CSV->new({binary => 1});
      $parser->parse($match);
      my @row1= $parser->fields();
      $thisrow{address} = $row1[2];
      $thisrow{address2} = $row1[3];
      $thisrow{city}     = $row1[7];
      $thisrow{state}    = $row1[8];
      $thisrow{zipcode}  = $row1[9];
      if (length $thisrow{zipcode} == 4){
         $thisrow{zipcode} = '0'.$row1[9];
      }
      $thisrow{B_address} = $row1[4];
      $thisrow{B_address2} = $row1[5];
      if ($row1[6] =~ /\@/){
         $thisrow{email} = $row1[6];
      }
      elsif ($row1[6] ne q{}){
         $thisrow{phonepro} = $row1[6];
      }
   }
  $debug and print "foo!"; 
   my @email_matches = qx{grep "^$matchpoint,3," $addressfile};
   foreach my $match (@email_matches){
      $debug and print $match;
      my $parser = Text::CSV->new();
      $parser->parse($match);
      my @row1= $parser->fields();
      $thisrow{email} = $row1[2];
   }

   my @phone_matches = qx{grep "^$matchpoint," $phonefile};
   foreach my $match (@phone_matches){
      $debug and print $match;
      my $parser = Text::CSV->new();
      $parser->parse($match);
      my @row1=$parser->fields();
      if ($row1[1] eq "Primary"){
         $thisrow{phone} = $row1[2];
      }
      if ($row1[1] eq "Mobile"){
         $thisrow{mobile} = $row1[2];
      }
      if ($row1[1] eq "Fax") {
         $thisrow{fax} = $row1[2];
      }
      if ($row1[1] eq "Other") {
         $thisrow{phonepro} = $row1[2];
      }
   } 
  
   if ($statfile ne q{}){ 
   my @stat_matches = qx{grep "^$matchpoint," $statfile};
   foreach my $match (@stat_matches){
      $debug and print $match;
      my $parser = Text::CSV->new();
      $parser->parse($match);
      my @row1=$parser->fields();
      $thisrow{sex} = $row1[1];
      $thisrow{branchcode} = $row1[2];
      if (exists $branch_map{$row1[2]}){
         $thisrow{branchcode} = $branch_map{$row1[2]};
      } 
   }
   }

   if (!$thisrow{branchcode}){
      $thisrow{branchcode}    = $fixed_branch;
   }

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

print "\n\n$i lines read.\n$written borrowers written.\n$no_barcode with no barcode.\n";
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
   my $limit  = shift;
   return undef if !$datein;
   return undef if $datein eq q{};
   my %months =(
                JAN => 1, FEB => 2,  MAR => 3,  APR => 4,
                MAY => 5, JUN => 6,  JUL => 7,  AUG => 8,
                SEP => 9, OCT => 10, NOV => 11, DEC => 12
               );
   my ($day,$monthstr,$year) = split /\-/, $datein;
   if ($year < $limit){
       $year +=2000;
   }
   else{
       $year +=1900;
   }
   return sprintf "%4d-%02d-%02d",$year,$months{uc $monthstr},$day;
}

