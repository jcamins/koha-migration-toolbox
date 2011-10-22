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
#   -primary input file, CSV, in THIS order:
#      Name and Address (^M separated),  Notes,                 Barcode,    Alternate ID,     Responsible party barcode and name,
#      Expiration date,                  Issue date,            Birthdate,  Email address,    Last activity date,
#      Registration branch,              Last activity branch,  UNDEF,      Total checkouts
#   -secondary input file, CSV, in THIS order:
#      UNDEF,  Borrower cateogory,  UNDEF,  Barcode,  UNDEF,
#      UNDEF,  UNDEF,               UNDEF,  UNDEF,    UNDEF,
#      UNDEF,  UNDEF,               Status
#   -phone data, CSV, in THIS order:
#      UNDEF,  Barcode,  Phone number
#   -Default branchcode
#   -Default borrower category
#   -Privacy value (Defaults to 1)
#   -optional branch map, CSV, in THIS order:
#      old branchcode,  new branchcode
#   -optional category map, CSV, in THIS order:
#      old categorycode,  new categorycode
#
# DOES:
#   -nothing
#
# CREATES:
#   -Patron CSV, ready for Koha import
#   -Patron responsibility connections, CSV, in this form:
#      borrower barcode,  guarantor barcode
#
# REPORTS:
#   -count of records read
#   -count of records output
#   -counts of branchcodes
#   -counts of categorycodes

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

local    $OUTPUT_AUTOFLUSH = 1;
Readonly my $NULL_STRING => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;

my $input_filename          = $NULL_STRING;
my $secondary_filename      = $NULL_STRING;
my $phone_filename          = $NULL_STRING;
my $output_filename         = $NULL_STRING;
my $responsibility_filename = $NULL_STRING;
my $branch_map_filename     = $NULL_STRING;
my $category_map_filename   = $NULL_STRING;
my $default_branch          = $NULL_STRING;
my $default_category        = $NULL_STRING;
my $default_privacy         = 1;

my %branch_map;
my %category_map;

GetOptions(
    'in=s'               => \$input_filename,
    'in2=s'              => \$secondary_filename,
    'phone=s'            => \$phone_filename,
    'out=s'              => \$output_filename,
    'resp=s'             => \$responsibility_filename,
    'branch_map:s'       => \$branch_map_filename,
    'category_map:s'     => \$category_map_filename,
    'default_category:s' => \$default_category,
    'default_branch:s'   => \$default_branch,
    'default_privacy:i'  => \$default_privacy,
    'debug'              => \$debug,
);

for my $var ($input_filename,          $secondary_filename, $phone_filename, $output_filename,
             $responsibility_filename, $default_category,   $default_branch ) {
   croak ("You're missing something.") unless $var ne $NULL_STRING;
}

if ($branch_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$branch_map_filename;
   while (my $row = $csv->getline($mapfile)) {
       my @data = @$row;
       $branch_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($category_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$category_map_filename;
   while (my $row = $csv->getline($mapfile)) {
       my @data = @$row;
       $category_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $csv = Text::CSV_XS->new({ binary => 1, eol => "\n" });

my @borrowers;
my %branch_counts;
my %category_counts;
my $written         = 0;
my $carryover       = $NULL_STRING;

my @borrower_fields = qw /cardnumber    surname            firstname 
                          address       address2           city
                          state         zipcode            email
                          phone         dateofbirth        branchcode
                          categorycode  dateenrolled       dateexpiry  
                          debarred      borrowernotes      password
                          userid        privacy
                         /;

open my $input_file         ,'<',$input_filename;
open my $output_file        ,'>',$output_filename;
open my $responsibility_file,'>',$responsibility_filename;

for my $j (0..scalar(@borrower_fields)-1){
   print {$output_file} $borrower_fields[$j].','
}
print {$output_file} "patron_attributes\n";

LINE:
while (my $line=readline($input_file)){
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $row_result = $csv->parse($line);
   my @data;
   if ($row_result){
      @data=$csv->fields();
   }
   else {
      my ($address,$rest) = split ',',$line,2;
      my $new_result=$csv->parse($rest);
      my @new_data = $csv->fields();
      @data = ($address,@new_data);
   }

   next LINE if $data[0] eq "Name";

   if ($data[2] eq $NULL_STRING) {
      $debug and print "Carryingover!\n";
      $carryover .= $data[0].'';
      next LINE;
   }
   my %thisborrower;
  
   $data[0]   = $carryover.$data[0];
   $carryover = $NULL_STRING; 

   $debug and print Dumper(@data);
   my ($line1,$line2,$line3,$line4) = split(//,$data[0]);
   $debug and print "$line1\n$line2\n$line3\n$line4\n";
   my $cityline = $line4 ? $line4
                : $line3 ? $line3
                :          $NULL_STRING;
   $line1 =~ /(.*) (.*)$/;
   $thisborrower{surname}   = ($2);
   $thisborrower{firstname} = ($1);
   if ($line1 =~ /\,/) {
      $line1 =~ /(.*)\,(.*)$/;
      $thisborrower{surname}   = ($2);
      $thisborrower{firstname} = ($1);
   }
   if(!$thisborrower{surname}){
      $thisborrower{surname}   = $line1;
      $thisborrower{firstname} = "NOFIRSTNAME";
   }

   $thisborrower{address}  = $line2;
   $thisborrower{address2} = $line4 ? $line3 : undef;

   if ($cityline){
      if ($cityline =~ /(.*), (.*)  (.*)$/) {
         $thisborrower{city}    = ($1);
         $thisborrower{state}   = ($2);
         $thisborrower{zipcode} = ($3);
      } 
      else {
         $thisborrower{city}    = $cityline;
      }
   }

   $thisborrower{borrowernotes} = $data[1];
   $thisborrower{cardnumber}    = $data[2];

   if ($data[3] ne $NULL_STRING) {
      $thisborrower{patron_attributes} = 'ALT_ID:'.$data[3];
   }
  
   if ($data[4] ne $NULL_STRING) {
      my ($guarantorbarcode,undef) = split / /,$data[4];
      if ($guarantorbarcode ne 'no'){
         print {$responsibility_file} "$thisborrower{cardnumber},$guarantorbarcode\n";
      }
   }

   $thisborrower{dateexpiry}    = _process_date($data[5]);
   $thisborrower{dateenrolled}  = _process_date($data[6]);
   $thisborrower{dateofbirth}   = _process_date($data[7]);
   $thisborrower{email}         = $data[8];

   $thisborrower{branchcode} = $branch_map{$data[10]} ? $branch_map{$data[10]} : $data[10];
   $branch_counts{ $thisborrower{branchcode} }++;

   my @matches = qx{grep ",$thisborrower{cardnumber}," $secondary_filename};
   if (scalar(@matches) == 0) {
      $thisborrower{categorycode} = $default_category;
   }
   else {
      my $result=$csv->parse($matches[0]);
      my @second_data = $result ? $csv->fields() : split /,/, $matches[0] ;
      $debug and print "$matches[0]\n";
      $debug and print Dumper(@second_data);
      $thisborrower{categorycode} = $category_map{$second_data[1]} ? $category_map{$second_data[1]} : $second_data[1];
      $thisborrower{debarred}     = $second_data[13] eq "Blocked"  ? 1                              : undef;
   }
   $category_counts{ $thisborrower{categorycode} }++;

   @matches = qx{grep ",$thisborrower{cardnumber}," $phone_filename};
   if (scalar(@matches) > 0) {
      my $result=$csv->parse($matches[0]);
      my @phone_data = $result ? $csv->fields() : split /,/, $matches[0] ;
      $thisborrower{phone} = $phone_data[2];
   }

   $thisborrower{privacy} = $default_privacy;

   for my $k (0..scalar(@borrower_fields)-1) {
      if ($thisborrower{$borrower_fields[$k]}) {
         $thisborrower{$borrower_fields[$k]} =~ s/\"/'/g;
         if ($thisborrower{$borrower_fields[$k]} =~ /,/) {
            print {$output_file}'"'.$thisborrower{$borrower_fields[$k]}.'"';
         }
         else {
            print {$output_file}$thisborrower{$borrower_fields[$k]};
         }
      }
      print {$output_file}",";
   }
   if ($thisborrower{patron_attributes}){
      $thisborrower{patron_attributes} =~ s/^,//;
      print {$output_file}'"'.$thisborrower{patron_attributes}.'"';
   }
   print {$output_file}"\n";
   $written++;
}
close $input_file;
close $output_file;
close $responsibility_file;

print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

open my $sql,'>','patron_codes.sql';
print "BRANCH COUNTS\n";
foreach my $kee (sort keys %branch_counts) {
   print "$kee: $branch_counts{$kee}\n";
   print {$sql} "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print "\nCATEGORY COUNTS\n";
foreach my $kee (sort keys %category_counts){
   print "$kee: $category_counts{$kee}\n";
   print {$sql} "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}

exit;

sub _process_date {
   my ($date) = @ARG;
   return if $date eq $NULL_STRING;
   my ($month,$day,$year) = split '/', $date;
   return sprintf "%d-%02d-%02d",$year,$month,$day;
}
