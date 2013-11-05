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
#
# DOES:
#   -nothing
#
# CREATES:
#   -data extracts for importing into a running Koha
#
# REPORTS:
#   -counts

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

use DBI;

use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Members;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $default_branch       = $NULL_STRING;
my $patron_map_name      = $NULL_STRING;
my $patron_code_map_name = $NULL_STRING;
my %patron_code_map;

my $database_name   = $NULL_STRING;
my $database_user   = $NULL_STRING;
my $database_pass   = $NULL_STRING;
my $output_filename = $NULL_STRING;
my $default_privacy = 2;

GetOptions(
    'db=s'     => \$database_name,
    'user=s'   => \$database_user,
    'pass=s'   => \$database_pass,
    'out=s'    => \$output_filename,
    'def_privacy'       => \$default_privacy,
    'def_branch=s'      => \$default_branch,
    'patron_map=s'      => \$patron_map_name,
    'patron_code_map=s' => \$patron_code_map_name,
    'debug'             => \$debug,
);

for my $var ($database_name,$database_user,$database_pass,$output_filename,$patron_map_name) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if ($patron_code_map_name){
   my $csv = Text::CSV_XS->new();
   open my $mapfile,"<$patron_code_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $patron_code_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my %patron_categories;
my %patron_branches;
open my $map_file,'>',$patron_map_name;
my @borrower_fields = qw /cardnumber surname firstname title othernames initials streetnumber streettype address address2 city  
                          state zipcode country email phone mobile fax emailpro phonepro dateofbirth branchcode categorycode dateenrolled 
                          dateexpiry debarred borrowernotes password userid opacnote contactnote privacy/;
open my $output_file,'>',$output_filename;

foreach my $field (@borrower_fields) {
   print {$output_file} "$field,";
}
print {$output_file} "patron_attributes\n";

my $dbh = DBI->connect("dbi:mysql:$database_name:localhost:3306",$database_user,$database_pass);

my $borrower_sth = $dbh->prepare("SELECT patronnumber, patroncardnumber, experationdate from patroncard where primarycard=1");
my $sth_2 = $dbh->prepare("SELECT lastname,firstname,middlename,patrontitle,dateofbirth,
                                  dateenrolled,patron.patrontype as category ,username,password FROM patron
                           WHERE patronnumber=?");
my $sth_3 = $dbh->prepare("SELECT streetaddress,pobox,city,country,stateprovince,postalcode FROM patronaddress
                           WHERE addresstype='primary' AND patronnumber=?");
my $sth_4 = $dbh->prepare("SELECT emailtype, patronemail from patronemail
                           WHERE emailtype in ('work','home') AND patronnumber=?");
my $sth_5 = $dbh->prepare("SELECT shortnote,note FROM patronnotes WHERE patronnumber=?");
my $sth_6 = $dbh->prepare("SELECT phonetype,patronphone FROM patronphone WHERE patronnumber=?");

$borrower_sth->execute();
RECORD:
while (my $record=$borrower_sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my %this_borrower;
   my $patronnumber = $record->{patronnumber};
   $this_borrower{cardnumber} = $record->{patroncardnumber};
   $this_borrower{dateexpiry} = $record->{experationdate};
   $this_borrower{privacy}    = $default_privacy;
   $this_borrower{branchcode} = $default_branch;
   print {$map_file} $record->{patronnumber}.','.$record->{patroncardnumber}."\n";

   $sth_2->execute($patronnumber);
   my $this_namerec = $sth_2->fetchrow_hashref();
   next RECORD if !$this_namerec;
   
   $this_borrower{surname} = $this_namerec->{lastname};
   $this_borrower{firstname} = $this_namerec->{firstname}.' '.$this_namerec->{middlename};
   $this_borrower{title} = $this_namerec->{patrontitle};
   $this_borrower{dateofbirth} = $this_namerec->{dateofbirth} if (exists $this_namerec->{datefobirth} && $this_namerec->{dateofbirth} ne '0000-00-00');
   $this_borrower{dateenrolled} = substr($this_namerec->{dateenrolled},0,10);
   $this_borrower{categorycode} = $this_namerec->{category};
   $this_borrower{username}     = $this_namerec->{username};
   $this_borrower{password}     = $this_namerec->{password};

   $sth_3->execute($patronnumber);
   my $this_addressrec = $sth_3->fetchrow_hashref();
   if ($this_addressrec) {
      $this_borrower{address} = $this_addressrec->{streetaddress};
      $this_borrower{city}    = $this_addressrec->{city};
      $this_borrower{state}   = $this_addressrec->{stateprovince};
      $this_borrower{zipcode} = $this_addressrec->{postalcode};
      my $box = $this_addressrec->{pobox};
      $box =~ s/P\.O\./P O/;
      if ($box =~ /^\d+$/) {
         $box = 'P.O. Box '.$box;
      }
      $this_borrower{address2} = $box;
   }

   $sth_4->execute($patronnumber);
   while (my $this_emailrec = $sth_4->fetchrow_hashref()) {
      $this_borrower{emailpro} = $this_emailrec->{patronemail} if ($this_emailrec->{emailtype} eq 'work');
      $this_borrower{email}    = $this_emailrec->{patronemail};
   }

   $sth_5->execute($patronnumber);
   my $notes=$NULL_STRING;
   while (my $this_notesrec = $sth_5->fetchrow_hashref()) {
      $this_borrower{borrowernotes} .= ' -- '.$this_notesrec->{shortnote}.' -- '.$this_notesrec->{note};
   }
   $notes =~ s/^ -- //;
   $this_borrower{borrowernotes} = $notes;

   $sth_6->execute($patronnumber);
   while (my $this_phonerec = $sth_6->fetchrow_hashref()) {
      $this_borrower{phonepro} = $this_phonerec->{patronphone} if ($this_phonerec->{phonetype} eq 'work');
      $this_borrower{phone}    = $this_phonerec->{patronphone};
   }

   if (exists $patron_code_map{$this_borrower{categorycode}}){
      $this_borrower{categorycode} =  $patron_code_map{$this_borrower{categorycode}};
   }

   $patron_categories{$this_borrower{categorycode}}++;
   $patron_branches{$this_borrower{branchcode}}++;

   foreach my $field (@borrower_fields) {
      if ($this_borrower{$field}) {
         $this_borrower{$field} =~ s/\"/'/g;
         $this_borrower{$field} =~ s///g;
         $this_borrower{$field} =~ s/\n//g;
         if ($this_borrower{$field} =~ /,/){
            print {$output_file} '"'.$this_borrower{$field}.'"';
         } else {
            print {$output_file} $this_borrower{$field};
         }
      }
      print {$output_file} ',';
   }
   print {$output_file} "\n";
}
close $output_file;
close $map_file;

print "\n$i records written.\n";
open my $out,">patron_codes.sql";
print $out "# Branches \n";
foreach my $kee (sort keys %patron_branches){
   print $out "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','NEW--$kee');\n";
}
print $out "# Patron Categories\n";
foreach my $kee (sort keys %patron_categories){
   print $out "INSERT INTO categories (categorycode,description) VALUES ('$kee','NEW--$kee');\n";
}
close $out;
print "\nPATRON BRANCHES:\n";
foreach my $kee (sort keys %patron_branches){
   print $kee.":   ".$patron_branches{$kee}."\n";
}
print "\nPATRON CATEGORIES:\n";
foreach my $kee (sort keys %patron_categories){
   print $kee.":   ".$patron_categories{$kee}."\n";
}

exit;

