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

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename      = $NULL_STRING;
my $output_filename     = $NULL_STRING;
my $barcode_filename    = $NULL_STRING;
my $city_map_filename   = $NULL_STRING;
my $branch_map_filename = $NULL_STRING;
my $default_branch      = 'UNKNOWN';
my $default_category    = 'UNKNOWN';

my %city_map;
my %state_map;
my %branch_map;

GetOptions(
    'in=s'               => \$input_filename,
    'out=s'              => \$output_filename,
    'barcode=s'          => \$barcode_filename,
    'city_map=s'         => \$city_map_filename,
    'branch_map=s'       => \$branch_map_filename,
    'default_branch=s'   => \$default_branch,
    'default_category=s' => \$default_category,
    'debug'              => \$debug,
);

for my $var ($input_filename,$output_filename,$barcode_filename,$default_branch,$default_category) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %barcode_hash;

Readonly my $FIELD_SEP    => chr(254);
Readonly my $SUBFIELD_SEP => chr(253);

if ($barcode_filename){
   open my $barcode_file,'<',$barcode_filename";
   while (my $line = readline($barcode_file)){
      my @columns=split /$FIELD_SEP/,$line;
      $barcode_hash{$columns[0]} = $columns[1];
   }
   close $barcode_file;
}

if ($city_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$city_map_filename";
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      $city_map{$data[0]}  = $data[1];
      $state_map{$data[0]} = $data[2];
   }
   close $map_file;
}

if ($branch_map_filename){
   my $csv = Text::CSV->new();
   open my $map_file,"<$branch_map_filename";
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $map_file;
}


my $csv_format = Text::CSV_XS->new({ sep_char => chr(254) });
$csv_format->column_names( qw( patronid        name     street    city      zipcode 
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
                               attr81          flag     attr83    flagdate ); 

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
print {$output_file} "patron_attributes\n";

open my $input_file,'<',$input_filename;
RECORD:
while (my $patron=$csv_format->getline_hr($input_file)){
   last RECORD if ($debug and $i>10);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "\n$i: ";
   $debug and print Dumper($row);

   my %thispatron;
   my $addedcode = $NULL_STRING;

   if (exists $branch_map{ $patron->{branchcode} }) {
      $patron->{branchcode} = $branch_map{ $patron->{branchcode} };
   }

   my $lost_barcode1 = $NULL_STRING;
   my $found         = 0;
   my @bars = split /$SUBFIELD_SEP/,$patron->{barcodes};
   foreach my $barcode (@bars) {
      if (exists $barcode_hash{$barcode};
         my $dynix_key = $barcode_hash{barcode};
         my $patron_id = $dynix_key;
         $patron_id =~ s/^\*//g;
         if ($tempkey eq $patron->{patronid}) {
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
   if ( (not exists ($thispatron{cardnumber}) && ($length($lost_barcode1) > 0) ) {
      $thispatron{cardnumber}   =  $lost_barcode1;
      $thispatron{lostbarcodes} =~ s/\|$lost_barcode1//g;
   }
   $thispatron{keep_barcodes} =~ s/^\|//g;
   $thispatron{lostbarcodes}  =~ s/^\|//g;
   if (not exists($thispatron{cardnumber}) {
      $thispatron{cardnumber} = "TEMP".$patron->{patronid};
   }       

   if ($patron->{name} =~ m/,/) {
      ($thispatron{surname},$thispatron{firstname} = split /,/,$patron->{name};
   }
   else {
      $thispatron{surname} = $patron->{name};
   }

   if ($patron->{guardan} =~ m/,/) {
      ($thispatron{altcontactsurname},$thispatron{altcontactfirstname}) = split /,/,$patron->{guardian};
   }
   else {
      $thispatron{altcontactsurname} = $patron->{guardian};
   }

   if (exists $city_map{ $patron->{city} }) {
      $thispatron{city}  = $city_map{ $patron->{city} };
      $thispatron{state} = $state_map{ $patron->{city} };
   }
   if (exists $city_map{ $patron->{altcity} }) {
      $thispatron{altcontactaddress3} = $city_map{ $patron->{altcity} };
      $thispatron{altcontactstate}    = $state_map{ $patron->{altcity} };
   }
   else {
      $thispatron{altcontactaddress3} = $patron->{altcity};
   }

   if (exists ($patron->{dates})) {
      my ($dateadd,undef,$dateexpire) = split /$SUBFIELD_SEP/,$patron->{dates};
      $thispatron{dateenrolled} = process_date($dateadd);
      $thispatron{dateexpiry}   = process_date($dateexpiry);
   }

   $thispatron{dateofbirth} = $process_date($patron->{birthdate});

   my ($thispatron{address},$thispatron{address2}                    = split /$SUBFIELD_SEP/,$patron->{street};
   ($thispatron{altcontactaddress1},$thispatron{altcontactaddress2}) = split /$SUBFIELD_SEP/,$patron->{altstreet};

   $patron->{borrowernotes} =~ s/$SUBFIELD_SEP/ -- /g;
   if ($patron->{employer}) {
      $patron->{borrowernotes} .= ' -- Employer: '.$patron->{employer};

   $patron_categories{$patron->{categorycode}}++;
   $patron_branches{$patron->{branchcode}}++;
   for my $j (0..scalar(@borrower_fields)-1){
      my $field = $NULL_STRING;
      if ($thispatron{$borrower_fields[$j]}) {
         $field = $thispatron{$borrower_fields[$j]; 
      }
      elsif ($patron->{$borrower_fields[$j]}) {
         $field = $patron->{$borrower_fields[$j]};
      }
         $field} =~ s/\"/'/g;
         if ($field =~ /,/){
            print {$output_file} '"'.$field.'"';
         }
         else{
            print {$output_file} $field;
         }
      }
      print $out ",";
   }
   if ($addedcode){
       print {$output_file} '"'."$addedcode".'"';
   }
   print {$output_file} "\n";
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
   return undef if !$datein;
   return undef if $datein eq q{};
   my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$datein);
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
