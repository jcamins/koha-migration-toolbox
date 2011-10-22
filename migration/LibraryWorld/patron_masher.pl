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
use Getopt::Long;
use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
use Text::CSV_XS;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $circfile_name = "";
my $cat_map_name = "";
my %cat_map;
my $dept_map_name = "";
my %dept_map;
my $def_branch = "";

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'circ=s'        => \$circfile_name,
    'cat_map=s'     => \$cat_map_name,
    'dept_map=s'    => \$dept_map_name,
    'def_branch=s'  => \$def_branch,
    'debug'         => \$debug,
);

if (($infile_name eq q{}) || ($outfile_name eq q{})){
  print "Something's missing.\n";
  exit;
}

my $mapcsv = Text::CSV_XS->new();

if ($cat_map_name ne q{}){
print "looking for cat map $cat_map_name\n";
   open my $mapfile,"<$cat_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $cat_map{$data[0]}=$data[1];
   }
   close $mapfile;
}

if ($dept_map_name ne q{}){
   open my $mapfile,"<$dept_map_name";
   while (my $row = $mapcsv->getline($mapfile)){
      my @data = @$row;
      $dept_map{$data[0]}=$data[1];
   }
   close $mapfile;
}
#print Dumper(%dept_map);

my $infl = IO::File->new($infile_name);
my $batch = MARC::Batch->new('USMARC',$infl);
$batch->warnings_off();
$batch->strict_off();
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('marc8');
my $i=0;
my $written=0;
my $no_940=0;
my %branch_counts;
my %category_counts;
my %deptcode_counts;
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
                          smsalertnumber      privacy/;

open my $out,">:utf8",$outfile_name;
for my $k (0..scalar(@borrower_fields)-1){
   print $out $borrower_fields[$k].',';
}
print $out "patron_attributes\n";

open my $circ,">",$circfile_name;
print $circ "borrowerbar,itembar,issuedate,date_due\n";


RECORD:
while () {
   #last if ($debug and $i > 99);
   my $record = $batch->next();
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($@){
      print "Bogusness skipped\n";
      next;
   }
   last unless ($record);

   my %thisborrower=();
   my $addedcode=q{};

   if (!$record->field("940")){
       $no_940++;
       next RECORD;
   }
  
   my $field = $record->field("940");

   $thisborrower{branchcode} = $def_branch || "UNKNOWN";
   $thisborrower{cardnumber} = $field->subfield('a');
   $thisborrower{categorycode} = $field->subfield('b');
   if (exists $cat_map{$thisborrower{categorycode}}){
      $thisborrower{categorycode} = $cat_map{$thisborrower{categorycode}};
   }
   $thisborrower{surname} = $field->subfield('c');
   $thisborrower{borrowernotes} = $field->subfield('d') || "";
   if ($field->subfield('e') =~ /^BLOCK/){
      my (undef,$reason) = split (/\//,$field->subfield('e'));
      $addedcode = "BLOCK:$reason";
   }
   my @emails = split (/;/,$field->subfield('f'));
   $thisborrower{email} = $emails[0];
   $thisborrower{emailpro} = $emails[1] || undef;
   $thisborrower{B_email} = $emails[2] || undef;

   $thisborrower{address} = $field->subfield('g');
   $thisborrower{city}    = $field->subfield('h');
   $thisborrower{state}   = $field->subfield('i');
   $thisborrower{zipcode} = $field->subfield('j');

   $thisborrower{borrowernotes} .= " -- ".$field->subfield('k');

   $thisborrower{phone} = $field->subfield('p');
   
   my $dept = $field->subfield('q');
   if (exists $dept_map{$dept}){
      $dept = $dept_map{$dept};
   }
   $addedcode .= ",DEPT:$dept";

   ($thisborrower{firstname}, $thisborrower{othernames}) = split (/\(/,$field->subfield('r'));
   $thisborrower{othernames} =~ s/\)// if $thisborrower{othernames};

   $branch_counts{$thisborrower{branchcode}}++;
   $category_counts{$thisborrower{categorycode}}++;
   for my $k (0..scalar(@borrower_fields)-1){
      if ($thisborrower{$borrower_fields[$k]}){
         $thisborrower{$borrower_fields[$k]} =~ s/\"/'/g;
         if ($thisborrower{$borrower_fields[$k]} =~ /,/){
            print $out '"'.$thisborrower{$borrower_fields[$k]}.'"';
         }
         else{
            print $out $thisborrower{$borrower_fields[$k]};
         }
      }
      print $out ",";
   }
   if ($addedcode){
      $addedcode =~ s/^,//;
      print $out '"'."$addedcode".'"';
   }
   print $out "\n";

   foreach my $field ($record->field('941')){
      my $thisbar = $field->subfield('b');
      my ($year,$month,$day);     
      $year = substr($field->subfield('d'),0,4);
      $month = substr($field->subfield('d'),4,2);
      $day = substr($field->subfield('d'),6,2);
      my $thisout= sprintf "%d-%02d-%02d",$year,$month,$day;
      
      my $thisdue="2050-12-31"; 
      if ($field->subfield('e') ne q{}){
         $year = substr($field->subfield('e'),0,4);
         $month = substr($field->subfield('e'),4,2);
         $day = substr($field->subfield('e'),6,2);
         $thisdue= sprintf "%d-%02d-%02d",$year,$month,$day;
      }
 
      print $circ "$thisborrower{cardnumber},$thisbar,$thisout,$thisdue\n";
   }
}
 
close $infl;
close $out;
close $circ;

print "\n\n$i patrons read.\n$no_940 patron recs with no 940.\n";
print "\nBRANCH COUNTS\n";
foreach my $kee (sort keys %branch_counts){
   print "$kee:  $branch_counts{$kee}\n";
}
print "\nCATEGORY COUNTS\n";
foreach my $kee (sort keys %category_counts){
   print "$kee:  $category_counts{$kee}\n";
}

