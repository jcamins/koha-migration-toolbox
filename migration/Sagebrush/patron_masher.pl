#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -edited by Joy Nelson
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $patron_cat_mapfile = "";
my %patron_cat_map;
my $branch = "";

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$patron_cat_mapfile,
    'branch=s'      => \$branch,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

if ($patron_cat_mapfile){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$patron_cat_mapfile";
   while (my $row = $csv->getline($mapfile)){
      my @data=@$row;
      $patron_cat_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $csv = Text::CSV->new();
open my $in,"<$infile_name";

my $i=0;
my $j=0;
my %profiles;
my $headerline = $csv->getline($in);
my @fields = @$headerline;
my @borrowers;
my %headerkees;

my %thisborrower = ();
my @borrower_fields = qw /cardnumber          surname
                          firstname           title
                          othernames          initials
                          streetnumber        streettype
                          address             address2
                          city                state
                          zipcode
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

while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   for (my $j=0;$j<scalar(@data);$j++){
      if ($branch){
         $thisborrower{'branchcode'} = $branch;
      }
      if ($fields[$j] eq "Surname"){
         $thisborrower{'surname'} = $data[$j];
         $thisborrower{'password'} = lc($data[$j]);  #lowercase name for password
      }
      if ($fields[$j] eq "FirstName") {
         $thisborrower{'firstname'} = $data[$j];
      }
      
#         if ($fields[$j] eq "Creation Date"){
#         my ($month,$day,$year) = split(/\//,$data[$j]);
#         if ($year <=11){ 
#            $year += 2000;
#         }
#         else {
#            $year += 1900;
#         }
#         $thisborrower{'dateenrolled'} = sprintf "%4d-%02d-%02d",$year,$month,$day;
#      }

      if ($fields[$j] eq "PatronId"){
         $thisborrower{'cardnumber'} = $data[$j];
         $thisborrower{'userid'}=$data[$j];
      }
      if ($fields[$j] eq "PatronType"){
         if (exists $patron_cat_map{$data[$j]}){
            $debug and warn "Swapping cat $data[$j] to $patron_cat_map{$data[$j]}.";
            $thisborrower{'categorycode'} = $patron_cat_map{$data[$j]};
            next;
         } 
         else {
            $thisborrower{'categorycode'} = $data[$j];
         }
      }
      if ($fields[$j] eq "Phone"){
         $thisborrower{'phone'} = $data[$j];
      }
      if ($fields[$j] eq "OtherPhone"){
         $thisborrower{'mobile'} = $data[$j];
      }
      if ($fields[$j] eq "Address1"){
         $thisborrower{'address'} = $data[$j];
      }
      if ($fields[$j] eq "Address2"){
         $thisborrower{'address2'} = $data[$j];
      }
      if ($fields[$j] eq "City"){
         $thisborrower{'city'} = $data[$j];
      }
      if ($fields[$j] eq "ProvinceState"){
         $thisborrower{'state'} = $data[$j];
      }
      if ($fields[$j] eq "PostalZip"){
         $thisborrower{'zipcode'} = $data[$j];
      }
      if ($fields[$j] eq "DateAdded"){
         $thisborrower{'dateenrolled'} = $data[$j];
      }

      if ($fields[$j] eq "PrivilegesExpire"){
         $thisborrower{'dateexpiry'} = $data[$j];
      }
      if ($fields[$j] eq "Email"){
         $thisborrower{'email'} = $data[$j];
      }
      if ($fields[$j] eq "Grade"){
         $thisborrower{'borrowernotes'} = $data[$j];
      }
      if ($fields[$j] eq "UserDefined1"){
         $thisborrower{'borrowernotes'} .= " " . $data[$j];
      }
      if ($fields[$j] eq "UserDefined2"){
         $thisborrower{'borrowernotes'} .= " " . $data[$j];
      }
      if ($fields[$j] eq "UserDefined4"){
         $thisborrower{'borrowernotes'} .= " " . $data[$j];
      }
      if ($fields[$j] eq "UserDefined5"){
         $thisborrower{'borrowernotes'} .= " " . $data[$j];
      }
      #set patron privacy to NEVER
      $thisborrower{'privacy'} = 2;
   }
      $j++;
      push @borrowers,{%thisborrower};
      foreach my $kee ( sort keys %thisborrower){
         $headerkees{$kee} = 1;
      }
}
print "\n\n$i lines read.\n$j borrowers found.\n";

open my $out,">$outfile_name";
foreach my $kee (sort keys %headerkees){
   print $out $kee.",";
}
print $out "\n";
for (my $j=0;$j<scalar(@borrowers);$j++){
   foreach my $kee (sort keys %headerkees){
      if ($borrowers[$j]{$kee}){
         $borrowers[$j]{$kee} =~ s/\"/'/g;
         if ($borrowers[$j]{$kee} =~ /,/){
            print $out '"'.$borrowers[$j]{$kee}.'",';
            next;
         }
         else{
            print $out $borrowers[$j]{$kee};
         }
      }
      print $out ",";
   }
   print $out "\n";
}
close $in;
close $out;
exit;

