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
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use autodie qw(open close);
use Getopt::Long;
use Readonly;
use Smart::Comments;
use Text::CSV_XS;
use Text::CSV::Simple;
use MARC::Field;
use MARC::Record;
use XML::Simple;
use version; our $VERSION = qv('1.0.0');

$OUTPUT_AUTOFLUSH = 1;
Readonly my $FIELD_SEPARATOR => q{,};
Readonly my $NULL_STRING     => q{};
my $debug = 0;

my $infile_name  = q{};
my $outfile_name = q{};
my $branch = q{};
my $branch_map_name = "";
my %branch_map;
my $category_map_name = "";
my %category_map;

my $csv = Text::CSV_XS->new();
GetOptions(
    'in=s'           => \$infile_name,
    'out=s'          => \$outfile_name,
    'branch=s'       => \$branch,
    'branch_map=s'   => \$branch_map_name,
    'category_map=s' => \$category_map_name,
    'debug'          => \$debug,
);

if ( ( $infile_name eq $NULL_STRING ) 
     || ( $outfile_name eq $NULL_STRING )
     || ( $branch eq $NULL_STRING )) {
    print "Something's missing.\n";
    exit;
}

if ($branch_map_name){
    my $csv = Text::CSV_XS->new();
    open my $mapfile,"<$branch_map_name";
    while (my $row = $csv->getline($mapfile)){
        my @data = @$row;
        $branch_map{$data[0]} = $data[1];
    }
    close $mapfile;
}

if ($category_map_name){
    my $csv = Text::CSV_XS->new();
    open my $mapfile,"<$category_map_name";
    while (my $row = $csv->getline($mapfile)){
        my @data = @$row;
        $category_map{$data[0]} = $data[1];
    }
    close $mapfile;
}

my $read        = 0;
my $written     = 0;
my %patron_branches;
my %patron_categories;

$csv->column_names( qw /expiry undef undef undef type
                       undef undef undef undef recnum enrolled
                       undef undef message name addr1
                       addr2 phone phonepro email undef
                       undef undef note barcode/);

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

## no critic (InputOutput::RequireBriefOpen)
open my $infl, '<',      $infile_name;
open my $outfl,  '>:utf8', $outfile_name;
## use critic

for my $j (0..scalar(@borrower_fields)-1){
    print {$outfl} $borrower_fields[$j].',';
}
print {$outfl} "patron_attributes\n";

RECORD:
while ( my $row = $csv->getline_hr($infl) ) {
    last RECORD if ($debug and $read > 9);
    $read++;
    ($read % 100) ? print '.' : print "\r$read";
    my $addedcode;
    my %thisrow;
   $thisrow{branchcode}    = $branch;
   $thisrow{email}         = $row->{email};
   $thisrow{phone}         = $row->{phone};
   $thisrow{phonepro}      = $row->{phonepro};
   
   $thisrow{password}      = substr $row->{barcode},-4;
   $thisrow{categorycode}  = uc($row->{type});
   $thisrow{dateenrolled} = _process_date($row->{enrolled});
   $thisrow{dateexpiry}   = _process_date($row->{expiry});
   
   $thisrow{cardnumber}    = $row->{barcode} ? $row->{barcode} : $row->{recnum};
   $thisrow{userid}        = $row->{barcode} ? $row->{barcode} : $row->{recnum};
   
   ($thisrow{surname},$thisrow{firstname}) = split /,/, $row->{name} ,2;
   
   if ($category_map{uc($row->{type})}){
      $thisrow{categorycode} = $category_map{uc($row->{type})};
   }

   ($thisrow{address}  ,$thisrow{address2},
    $thisrow{city}     ,$thisrow{zipcode}  )   = _process_address($row->{addr2});
   ($thisrow{B_address},$thisrow{B_address2},
    $thisrow{B_city}   ,$thisrow{B_zipcode}  ) = _process_address($row->{addr1});

   $patron_categories{$thisrow{categorycode}}++;
   $patron_branches{$thisrow{branchcode}}++;
   for my $j (0..scalar(@borrower_fields)-1){
      if ($thisrow{$borrower_fields[$j]}){
         $thisrow{$borrower_fields[$j]} =~ s/\"/'/g;
         if ($thisrow{$borrower_fields[$j]} =~ /,/){
            print {$outfl} '"'.$thisrow{$borrower_fields[$j]}.'"';
         }
         else{
            print {$outfl} $thisrow{$borrower_fields[$j]};
         }
      }
      print {$outfl} ",";
   }
   if ($addedcode){
       print {$outfl} '"'."$addedcode".'"';
   }
    print {$outfl} "\n";
    $written++;
}
close $infl;
close $outfl;

print "\n$read lines read.\n$written borrowers written.\n";

open my $sql,">patron_sql.sql";
print "\nResults by branchcode:\n";
foreach my $kee (sort keys %patron_branches){
    print $sql "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','NEW--$kee');\n";
    print $kee.":  ".$patron_branches{$kee}."\n";
}
print "\nResults by categorycode:\n";
foreach my $kee (sort keys %patron_categories){
    print $kee.":  ".$patron_categories{$kee}."\n";
    print $sql "INSERT INTO categories (categorycode,description) VALUES ('$kee','NEW--$kee');\n";
}
close $sql;

exit;

sub _process_date {
   my $datein = shift;
   my ($date,undef) = split(/ /,$datein);
   my ($month,$day,$year)= split(/-/,$date);
   $year += 1900 if $year <100;
   my $fixeddate = sprintf "%4d-%02d-%02d",$year,$month,$day;
   return $fixeddate;
}

sub _process_address {
   my $addrin = shift;
   return (undef,undef,undef,undef) if ($addrin eq $NULL_STRING);
   $addrin =~ s/\//\$/g;
   $addrin =~ s/\$$//g;
   $addrin =~ s/C\$[oO]/C\/O/g;
   $addrin =~ s/G\$F/G\/F/g;
   $addrin =~ s/\$\$/\$/g;
   $addrin =~ s/\$\,$//;
   my $addr1;
   my $addr2;
   my $city;
   my $zip;
   my @addrlines = split /\$/,$addrin;
   $city = $addrlines[scalar(@addrlines)-1] || "";
   if ($city =~ / (\d{5})$/){
      $zip = $1;
      $city =~ s/ $zip//;
   }
   elsif ($city =~ / (\d{5}-\d{4})$/){
      $zip = $1;
      $city =~ s/ $zip//;
   }
   if (scalar(@addrlines) == 2 ){
      $addr1 = $addrlines[0];
   }
   if (scalar(@addrlines) == 3 ){
      $addr1 = $addrlines[0];
      $addr2 = $addrlines[1];
   }
   if (scalar(@addrlines) == 4){
      $addr1 = $addrlines[0].','.$addrlines[1];
      $addr2 = $addrlines[2];
   }
   if (scalar(@addrlines) == 5){
      $addr1 = $addrlines[0].','.$addrlines[1];
      $addr2 = $addrlines[2].','.$addrlines[3];
   }
   if (scalar(@addrlines) > 5){
      print "\n$addrin\n";
   }
   return ($addr1,$addr2,$city,$zip);
}
