#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -nothing

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use Date::Calc qw(Add_Delta_Days);

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename      = $NULL_STRING;
my $output_filename     = $NULL_STRING;
my $pass_filename       = $NULL_STRING;
my $attrib_filename     = $NULL_STRING;
my $barcode_filename    = $NULL_STRING;
my $city_map_filename   = $NULL_STRING;
my $branch_map_filename = $NULL_STRING;
my $category_map_filename = $NULL_STRING;
my $default_branch      = 'UNKNOWN';
my $default_category    = 'UNKNOWN';
my $default_privacy     = 2;

my %city_map;
my %state_map;
my %branch_map;
my %category_map;

GetOptions(
    'in=s'               => \$input_filename,
    'out=s'              => \$output_filename,
    'pass=s'             => \$pass_filename,
    'attrib=s'           => \$attrib_filename,
    'barcode=s'          => \$barcode_filename,
    'city_map=s'         => \$city_map_filename,
    'branch_map=s'       => \$branch_map_filename,
    'category_map=s'     => \$category_map_filename,
    'default_branch=s'   => \$default_branch,
    'default_category=s' => \$default_category,
    'default_privacy=s'  => \$default_privacy,
    'debug'              => \$debug,
);

for my $var ($input_filename,$output_filename,$pass_filename,$attrib_filename,$barcode_filename,$default_branch,$default_category) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %barcode_hash;

Readonly my $CSV_SEP      => '\|';
Readonly my $FIELD_SEP    => chr(254);
Readonly my $SUBFIELD_SEP => chr(253);

if ($barcode_filename){
   open my $barcode_file,'<',$barcode_filename;
   while (my $line = readline($barcode_file)){
      my @columns=split /$FIELD_SEP/,$line;
      $barcode_hash{$columns[0]} = $columns[1];
   }
   close $barcode_file;
}
#$debug and warn Dumper(%barcode_hash);

if ($city_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$city_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      $city_map{$data[0]}  = $data[1];
      $state_map{$data[0]} = $data[2];
   }
   close $map_file;
}
#$debug and warn Dumper(%city_map);

if ($branch_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$branch_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $map_file;
}

if ($category_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$category_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      $category_map{$data[0]} = $data[1];
   }
   close $map_file;
}

my @column_names =         qw/ patronid        name     street    city      zipcode 
                               barcodes        dates    lastuse   usage     categorycode
                               pstat           guardian itemout   pin       phone
                               branchcode      attr16   attr17    attr18    attr19
                               attr20          id       attr22    attr23    attr24
                               attr25          attr26   email     birthdate attr29
                               attr30          attr31   altstreet altcity   altcontactzipcode
                               altcontactphone borrowernotes    attr37    attr38    attr39
                               attr40          employer attr42    attr43    attr44
                               attr45          attr46   attr47    attr48    attr49
                               attr50          attr51   attr52    attr54    attr55
                               attr55          attr56   attr57    attr58    attr59
                               attr60          attr61   attr62    attr64    attr65
                               attr65          attr66   attr67    attr68    attr69
                               attr70          attr71   attr72    attr73    attr74
			       attr75          attr76   attr77    attr78    attr79
                               attr81          flag     attr83    flagdate/ ; 

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
                          altcontactaddress3  atlcontactstate    altcontactzipcode 
                          altcontactcountry   altcontactphone
                          smsalertnumber      privacy/;

my $no_barcode = 0;

open my $output_file,'>:utf8',$output_filename;
for my $j (0..scalar(@borrower_fields)-1){
   print {$output_file} $borrower_fields[$j].',';
}
print {$output_file} "\n";

open my $attrib_file,'>:utf8',$attrib_filename;
open my $pass_file,'>:utf8',$pass_filename;

open my $input_file,'<',$input_filename;
RECORD:
while (my $line = readline($input_file)){
   last RECORD if ($debug and $i>10);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   #$debug and print "\n$i: ";
   
   my %thispatron;

   chomp $line;
   $line =~ s///g;
   my @columns = split /$FIELD_SEP/,$line;
   for my $j (0..scalar(@column_names)-1) {
      $thispatron{$column_names[$j]} = $columns[$j] || $NULL_STRING;
   }
   my $addedcode = $NULL_STRING;

   if (exists $branch_map{ $thispatron{branchcode} }) {
      $thispatron{branchcode} = $branch_map{ $thispatron{branchcode} };
   }

   if (exists $category_map{ $thispatron{categorycode} }) {
      $thispatron{categorycode} = $category_map{ $thispatron{categorycode} };
   }

   my $lost_barcode1 = $NULL_STRING;
   my $found         = 0;
   $thispatron{keep_barcodes} = $NULL_STRING;
   $thispatron{lostbarcodes} = $NULL_STRING;
   $debug and print "BARCODES $thispatron{barcodes}\n";
   my @bars = split /$SUBFIELD_SEP/,$thispatron{barcodes};

   foreach my $barcode (@bars) {
      $debug and print "BAR $barcode\n";
      if (exists $barcode_hash{$barcode}) {
         $debug and print "FOUND\n";
         my $dynix_key = $barcode_hash{$barcode};
         my $patron_id = $dynix_key;
         $patron_id =~ s/^\*//g;
         $debug and print "PATRON_ID: $patron_id  PATRON: $thispatron{patronid}\n";
         if ($patron_id eq $thispatron{patronid}) {
            if (substr($dynix_key,0,1) ne '*') {  #non-lost barcode
               if (!$found) {
                  $thispatron{cardnumber} = $barcode;
                  $found = 1;
               } 
               else {   #hang on to these non-primary valid barcodes
                  $thispatron{keep_barcodes} .= '|'.$barcode;
               }
            }
            else {  #lost barcode
               $thispatron{lostbarcodes} .= '|'.$barcode;
               $lost_barcode1 = $barcode;
            }
         }
      }
   }
   if ( (not exists ($thispatron{cardnumber})) && (length($lost_barcode1) > 0) ) {
      $thispatron{cardnumber}   =  $lost_barcode1;
      $thispatron{lostbarcodes} =~ s/\|$lost_barcode1//g;
   }
   $thispatron{keep_barcodes} =~ s/^\|//g;
   foreach my $okay_barcode (split /\|/,$thispatron{keep_barcodes}) {
      $addedcode .= ',GOODBAR:'.$okay_barcode;
   }

   $thispatron{lostbarcodes}  =~ s/^\|//g;
   if (not exists($thispatron{cardnumber})) {
      $thispatron{cardnumber} = "TEMP".$thispatron{patronid};
   }       

   if ($thispatron{name} =~ m/,/) {
      ($thispatron{surname},$thispatron{firstname}) = split /,/,$thispatron{name};
      $thispatron{firstname} =~ s/^ //;
   }
   else {
      $thispatron{surname} = $thispatron{name};
   }

   if ($thispatron{guardian} =~ m/,/) {
      ($thispatron{altcontactsurname},$thispatron{altcontactfirstname}) = split /,/,$thispatron{guardian};
      $thispatron{altcontactfirstname} =~ s/^ //;
   }
   else {
      $thispatron{altcontactsurname} = $thispatron{guardian};
   }

   if (exists $city_map{ $thispatron{city} }) {
      $thispatron{state} = $state_map{ $thispatron{city} };
      $thispatron{city}  = $city_map{ $thispatron{city} };
   }
   if (exists $city_map{ $thispatron{altcity} }) {
      $thispatron{altcontactaddress3} = $city_map{ $thispatron{altcity} };
      $thispatron{altcontactstate}    = $state_map{ $thispatron{altcity} };
   }
   else {
      $thispatron{altcontactaddress3} = $thispatron{altcity};
   }

   if (exists ($thispatron{dates})) {
      my ($dateadd,undef,$dateexpire) = split /$SUBFIELD_SEP/,$thispatron{dates};
      $thispatron{dateenrolled} = _process_date($dateadd);
      $thispatron{dateexpiry}   = _process_date($dateexpire);
   }

   $thispatron{dateofbirth} = _process_date($thispatron{birthdate});

   ($thispatron{address},$thispatron{address2})                      = split /$SUBFIELD_SEP/,$thispatron{street};
   ($thispatron{altcontactaddress1},$thispatron{altcontactaddress2}) = split /$SUBFIELD_SEP/,$thispatron{altstreet};

   $thispatron{borrowernotes} =~ s/$SUBFIELD_SEP/ | /g;
   if ($thispatron{employer}) {
      $thispatron{borrowernotes} .= ' | Employer: '.$thispatron{employer};
   }

   if ($thispatron{branchcode} eq $NULL_STRING) {
      $thispatron{branchcode} = $default_branch;
   }
   if ($thispatron{categorycode} eq $NULL_STRING) {
      $thispatron{categorycode} = $default_category;
   }
   $thispatron{privacy} = $default_privacy;
   $thispatron{sort1} = $thispatron{patronid};

   $patron_categories{$thispatron{categorycode}}++;
   $patron_branches{$thispatron{branchcode}}++;
   for my $j (0..scalar(@borrower_fields)-1){
      my $field = $NULL_STRING;
      if ($thispatron{$borrower_fields[$j]}) {
         $field = $thispatron{$borrower_fields[$j]}; 
      }
      $field =~ s/\"/'/g;
      if ($field =~ /,/){
         print {$output_file} '"'.$field.'"';
      }
      else{
         print {$output_file} $field;
      }
      print {$output_file} ",";
   }
   print {$output_file} "\n";
    
   print {$pass_file} $thispatron{cardnumber}.','.$thispatron{pin}."\n";

   if ($addedcode){
       $addedcode =~ s/^,//;
       print {$attrib_file} $thispatron{cardnumber}.',"'."$addedcode".'"'."\n";
   }
   $written++;
}

close $input_file;
close $output_file;

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
   return undef if !$datein;
   return undef if $datein eq q{};
   return undef if $datein < 0;
   my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$datein);
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
