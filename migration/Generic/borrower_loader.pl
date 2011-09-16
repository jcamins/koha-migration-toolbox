#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# Draws heavily on Koha's tools/import_borrower.pl
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Branch;
use C4::Dates;
use C4::Members;
use C4::Members::Attributes;
use C4::Members::Attributes qw /extended_attributes_code_value_arrayref/;
use C4::Members::AttributeTypes;
my $debug=0;
my $doo_eet=0;
$|=1;

my $input_file="";
my $err_file="";

GetOptions(
    'in=s'          => \$input_file,
    'err=s'         => \$err_file,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

if (($input_file eq '') || ($err_file eq '')){
   print "Something's missing.\n";
   exit;
}

my $i=0;
my $attempted_write=0;
my $written=0;
my $other_problem=0;
my $broken_records=0;
my $duplicate_borrowers=0;
my $dbh=C4::Context->dbh();
my $csv=Text::CSV->new({binary => 1});
my $today_iso=C4::Dates->new()->output('iso');
my $date_re = C4::Dates->new->regexp('syspref');
my $iso_re = C4::Dates->new->regexp('iso');
my $extended = C4::Context->preference('ExtendedPatronAttributes');
my $set_messaging_prefs = C4::Context->preference('EnhancedMessagingPreferences');
my @columnkeys=C4::Members->columns;

open my $in,"<$input_file";
open my $err,">$err_file";

my $headerline = $csv->getline($in);
my @csvcolumns = @$headerline;
my %csvkeycol;
my $col=0;
foreach my $keycol (@csvcolumns){
   $keycol =~ s/ +//g;
   $csvkeycol{$keycol} = $col++;
}
if ($extended) {
    push @columnkeys, 'patron_attributes';
}

RECORD:
while (my $line=$csv->getline($in)){
   $debug and last if ($i > 0);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my %borrower;
   my $patron_attributes;
   my $bad_record = 0;
   my $message = '';
   my @columns = @$line; 
   foreach my $key (@columnkeys){
      if (defined($csvkeycol{$key}) and $columns[$csvkeycol{$key}] =~ /\S/){
         $borrower{$key} = $columns[$csvkeycol{$key}];
      }
      else {
         $borrower{$key} = '';
      }
   }
   if ($borrower{categorycode}){
      if (!GetBorrowercategory($borrower{categorycode})){
         $bad_record = 1;
         $message .= "/Borrower category unknown";
      }
   }
   else {
      $bad_record = 1;
      $message .= "/Borrower category missing";
   }
   if ($borrower{branchcode}){
      if (!GetBranchName($borrower{branchcode})){
         $bad_record = 1;
         $message .= "/Borrower branch unknown";
      }
   }
   else {
      $bad_record = 1;
      $message .= "/Borrower branch missing";
   }
   if (!$borrower{surname}){
      $bad_record = 1;
      $message .= "/Surname undefined";
   }
   if ($bad_record){
      print $err "PROBLEM RECORD #".$i.":\n".$message."\n";
      print $err Dumper(%borrower);
      $broken_records++;
      next RECORD;
   }
   if ($extended) {
      my $attr_str = $borrower{patron_attributes};
      delete $borrower{patron_attributes}; 
      $patron_attributes = extended_attributes_code_value_arrayref($attr_str);
   }
   foreach (qw(dateofbirth dateenrolled dateexpiry)) {
      my $tempdate = $borrower{$_} or next;
      if ($tempdate =~ /$date_re/) {
         $borrower{$_} = format_date_in_iso($tempdate);
      } elsif ($tempdate =~ /$iso_re/) {
         $borrower{$_} = $tempdate;
      } else {
         $borrower{$_} = '';
      }
   }
   $borrower{dateenrolled} = $today_iso unless $borrower{dateenrolled};
   $borrower{dateexpiry} = GetExpiryDate($borrower{categorycode},$borrower{dateenrolled}) unless $borrower{dateexpiry};

   my $borrowernumber;

   $debug and print "WRITTEN: $borrower{cardnumber}\n";
   $attempted_write++;

   my $member = GetMember( 'cardnumber' => $borrower{'cardnumber'});
   if ($member){
      print $err "DUPLICATE CARDNUMBER--RECORD #".$i.":\n";
      print $err Dumper(%borrower);
      $duplicate_borrowers++;
      next RECORD;
   }

   if ($doo_eet){
      if ($borrowernumber = AddMember(%borrower)) {
         if ($extended) {
            C4::Members::Attributes::SetBorrowerAttributes($borrowernumber, $patron_attributes);
         }
         if ($set_messaging_prefs) {
            C4::Members::Messaging::SetMessagingPreferencesFromDefaults({ borrowernumber => $borrowernumber,
                                                                          categorycode => $borrower{categorycode} });
         }
         $written++;
      } else {
         print $err "ERROR WITH ADDMEMBER--RECORD #".$i.":\n";
         print $err Dumper(%borrower);
         $other_problem++;
      }
   }
}
close $in;
close $err;
print "\n\n$i borrowers found.\n";
print "$attempted_write borrowers potentially written.\n$written new borrowers written.\n";
print "$duplicate_borrowers borrowers not written due to duplicate cardnumber.\n";
print "$broken_records invalid records found.\n";
print "$other_problem records could not be added by AddMember.\n";
