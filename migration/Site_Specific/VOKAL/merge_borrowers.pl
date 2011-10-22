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
my $branch="";
my $bar_fixes="";
my $name_fixes="";
my $test_mode=0;
my $override="";

GetOptions(
    'in=s'          => \$input_file,
    'err=s'         => \$err_file,
    'branch=s'      => \$branch,
    'bar_fixes=s'   => \$bar_fixes,
    'name_fixes=s'  => \$name_fixes,
    'test_mode'     => \$test_mode,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
    'override=s'    => \$override,
);

if (($input_file eq '') || ($err_file eq '') || ($branch eq '')){
   print "Something's missing.\n";
   exit;
}

if (!$test_mode && (($bar_fixes eq "" || $name_fixes eq "") && ($override eq ""))){
   print "Something's missing.\n";
   exit;
}

my $i=0;
my $attempted_write=0;
my $written=0;
my $attempted_overlay=0;
my $attempted_kept=0;
my $def_overlaid=0;
my $def_kept=0;
my $other_problem=0;
my $broken_records=0;
my $dupe_barcodes=0;
my $dupe_names=0;
my $overlaid=0;
my $do_overlaid=0;
my $unclear=0;
my $bo_overlaid=0;
my $both_used=0;
my $notes_merged=0;
my $ignored=0;
my %by_command;
my %barmap;
my %namemap;
my $dbh=C4::Context->dbh();
my $csv=Text::CSV->new();
my $today_iso=C4::Dates->new()->output('iso');
my $date_re = C4::Dates->new->regexp('syspref');
my $iso_re = C4::Dates->new->regexp('iso');
my $extended = C4::Context->preference('ExtendedPatronAttributes');
my $set_messaging_prefs = C4::Context->preference('EnhancedMessagingPreferences');
my @columnkeys=C4::Members->columns;
my $dupl_sth = $dbh->prepare("SELECT * FROM borrowers WHERE 
                              SUBSTRING(UPPER(firstname),1,10)=SUBSTRING(UPPER(?),1,10) AND 
                              SUBSTRING(UPPER(surname),1,10)=SUBSTRING(UPPER(?),1,10) AND 
                              SUBSTRING(UPPER(city),1,10)=SUBSTRING(UPPER(?),1,10) AND cardnumber!=?");

open my $in,"<$input_file";
open my $err,">$err_file";
my $duplname;
my $duplbar;
if ($test_mode){
   open $duplname,">merge_duplname.csv";
   open $duplbar,">merge_duplbar.csv";
   print $duplname "action,incoming bar,incoming branch,incoming firstname,incoming surname,incoming city,,union bar,union branch,union firstname,union surname,union city\n";
   print $duplbar "action,incoming bar,incoming branch,incoming firstname,incoming surname,incoming city,,union bar,union branch,union firstname,union surname,union city\n";
}
else{
   open my $mapfile,"<$bar_fixes";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $barmap{$data[1]} = uc($data[0]);
   }
   close $mapfile;
   open $mapfile,"<$name_fixes";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      my $borrkey = uc($data[4])."|".uc(substr($data[3],0,5));
      $namemap{$borrkey} = uc($data[0]);
   }
   close $mapfile;
}

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

while (my $line=$csv->getline($in)){
   $debug and last if ($debug >1);
   $i++;
   print ".";
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
      next;
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
   my $member;
   my $thisaction="";
   $member = GetMember( 'cardnumber' => $borrower{'cardnumber'});
   if ($member){
      $member->{'firstname'} = "" if (!$member->{'firstname'});
      $member->{'firstname'} =~ /(\w+)/g;
      my $mfirstname= $1;
      $mfirstname="" if (!$mfirstname);
      $borrower{firstname}=~ /(\w+)/g;
      my $bfirstname= $1;
      $bfirstname="" if (!$bfirstname);
      if (uc($member->{'surname'}) ne uc($borrower{'surname'}) ||
         uc(substr($mfirstname,0,5)) ne uc(substr($bfirstname,0,5))){
         if ($test_mode){
            print $duplbar ",$borrower{cardnumber},$borrower{branchcode},\"$borrower{firstname}\",\"$borrower{surname}\",\"$borrower{city}\",,";
            print $duplbar "$member->{cardnumber},$member->{branchcode},\"$member->{firstname}\",\"$member->{surname}\",\"$member->{city}\"\n";
            $dupe_barcodes++;
         }
         elsif (exists $barmap{$borrower{cardnumber}}){
            $thisaction=$barmap{$borrower{cardnumber}};
            $by_command{$thisaction}++;
         }
         elsif ($override ne q{}){
            $thisaction=$override;
            $by_command{$thisaction}++;
         }
         else {
            print $err "UNHANDLED DUPICATE BARCODE--RECORD #".$i.":".uc($member->{'surname'})."~".uc($borrower{'surname'})."~";
            print $err uc(substr($mfirstname,0,5))."~".uc(substr($bfirstname,0,5))."\n";
            $dupe_barcodes++;
            next;
         }
      } 
      else {
         if ($borrower{branchcode} eq $branch){
            $thisaction="OVERLAY-DEF";
            $attempted_overlay++;
         }
         else{
            $thisaction="KEEP-DEF";
            $attempted_kept++;
         }
      }
   }
   else {
      $dupl_sth->execute($borrower{firstname},$borrower{surname},$borrower{city},$borrower{cardnumber});
      $member = $dupl_sth->fetchrow_hashref();
      if ($member){
         my $borrkey = uc($borrower{surname})."|".uc(substr($borrower{firstname},0,5));
         if ($test_mode){
            print $duplname ",$borrower{cardnumber},$borrower{branchcode},\"$borrower{firstname}\",\"$borrower{surname}\",\"$borrower{city}\",,";
            print $duplname "$member->{cardnumber},$member->{branchcode},\"$member->{firstname}\",\"$member->{surname}\",\"$member->{city}\"\n";
            $dupe_names++;
         }
         elsif (exists $namemap{$borrkey}){
            $thisaction = $namemap{$borrkey};
            $by_command{$thisaction}++;
         }
         elsif ($override ne q{}){
            $thisaction=$override;
            $by_command{$thisaction}++;
         }
         else {
            print $err "UNHANDLED DUPICATE NAME--RECORD #".$i.":\n";
            $dupe_names++;
            next;
         }
      }
      else{
         $thisaction="WRITE";
         $attempted_write++;
      }
   }
   if (!$test_mode){
      if (!$borrower{'cardnumber'}) {
         $borrower{'cardnumber'} = fixup_cardnumber(undef);
      }
# valid actions:  WRITE,OVERLAY-DEF,KEEP-DEF,OVERLAY,DATA-ONLY,BARCODE-ONLY,KEEP,NOTHING
      my $done=0;
      if ($thisaction eq "WRITE"){
         $debug and print "WRITTEN: $borrower{cardnumber}\n";
         if ($doo_eet){
            if ($borrowernumber = AddMember(%borrower)) {
               if ($extended) {
                  C4::Members::Attributes::SetBorrowerAttributes($borrowernumber, $patron_attributes);
               }
               if ($set_messaging_prefs) {
                  C4::Members::Messaging::SetMessagingPreferencesFromDefaults({ borrowernumber => $borrowernumber,
                     categorycode => $borrower{categorycode} });
               }
            } else {
               $other_problem++;
               print $err "ERROR WITH ADDMEMBER--RECORD #".$i.":\n";
               print $err Dumper(%borrower);
            }
         }
         $written++;
         $done=1;
      }
      if ($thisaction eq "OVERLAY-DEF"){
         $debug and print "OVERLAY-DEF: $borrower{'cardnumber'}  $borrower{borrowernotes}\n";
         $borrower{borrowernumber} = $member->{'borrowernumber'};
         if ($borrower{borrowernotes} ne ""){
            if ($borrower{borrowernotes} eq $member->{borrowernotes}){
               $borrower{borrowernotes} = $branch.": ".$borrower{borrowernotes};
            }
            else{
               $borrower{borrowernotes} = $branch.": ".$borrower{borrowernotes}." -- ".$member->{'borrowernotes'};
            }
         }
         if ($doo_eet){
            &ModMember(%borrower);
         }
         $def_overlaid++;
         $done=1;
      }
      if ($thisaction eq "KEEP-DEF"){
         $debug and print "KEEP-DEF: $borrower{'cardnumber'}\n";
         my %overlayer;
         $overlayer{'borrowernumber'} = $member->{'borrowernumber'};
         if ($borrower{borrowernotes} ne ""){
            if (($borrower{borrowernotes} eq $member->{borrowernotes}) or ($member->{borrowernotes} eq ($branch.": ".$borrower{borrowernotes}." -- "))){
               $overlayer{borrowernotes} = $branch.": ".$borrower{borrowernotes};
            }
            else{
               $overlayer{borrowernotes} = $branch.": ".$borrower{borrowernotes}." -- ".$member->{'borrowernotes'};
            }
         }
         if ($doo_eet && exists($overlayer{borrowernotes})){
            &ModMember(%overlayer);
         }
         $def_kept++;
         $done=1;
      }
      if ($thisaction eq "OVERLAY"){
         $debug and print "OVERLAY: $borrower{'cardnumber'}\n";
         $borrower{borrowernumber} = $member->{'borrowernumber'};
         if (($borrower{borrowernotes} eq $member->{borrowernotes}) or ($member->{borrowernotes} eq ($branch.": ".$borrower{borrowernotes}." -- "))){
            if ($borrower{borrowernotes} eq $member->{borrowernotes}){
               $borrower{borrowernotes} = $branch.": ".$borrower{borrowernotes};
            }
            else{
               $borrower{borrowernotes} = $branch.": ".$borrower{borrowernotes}." -- ".$member->{'borrowernotes'};
            }
         }
         if ($doo_eet){
            &ModMember(%borrower);
         }
         $overlaid++;
         $done=1;
      }
      if ($thisaction eq "DATA-ONLY"){
         $debug and print "DATA-ONLY: $borrower{'cardnumber'}--$member->{'cardnumber'}\n";
         $borrower{borrowernumber} = $member->{'borrowernumber'};
         $borrower{cardnumber} = $member->{'cardnumber'};
         if (($borrower{borrowernotes} eq $member->{borrowernotes}) or ($member->{borrowernotes} eq ($branch.": ".$borrower{borrowernotes}." -- "))){
            if ($borrower{borrowernotes} eq $member->{borrowernotes}){
               $borrower{borrowernotes} = $branch.": ".$borrower{borrowernotes};
            }
            else{
               $borrower{borrowernotes} = $branch.": ".$borrower{borrowernotes}." -- ".$member->{'borrowernotes'};
            }
         }
         if ($doo_eet){
            &ModMember(%borrower);
         }
         $do_overlaid++;
         $done=1;
      }
      if ($thisaction eq "BARCODE-ONLY"){
         $debug and print "BARCODE-ONLY: $borrower{'cardnumber'}--$member->{'cardnumber'}\n";
         my %overlayer;
         $overlayer{'borrowernumber'} = $member->{'borrowernumber'};
         $overlayer{'cardnumber'} = $borrower{'cardnumber'};
         if ($borrower{borrowernotes} ne ""){
            if (($borrower{borrowernotes} eq $member->{borrowernotes}) or ($member->{borrowernotes} eq ($branch.": ".$borrower{borrowernotes}." -- "))){
               $overlayer{borrowernotes} = $branch.": ".$borrower{borrowernotes};
            }
            else{
               $overlayer{borrowernotes} = $branch.": ".$borrower{borrowernotes}." -- ".$member->{'borrowernotes'};
            }
         }
         if ($doo_eet){
            &ModMember(%overlayer);
         }
         $bo_overlaid++;
         $done=1;
      }
      if ($thisaction eq "BOTH"){    #TODO
         if ($doo_eet){
            #NOP
         }
         $both_used++;
         $done=1;
      }
      if ($thisaction eq "KEEP"){
         $debug and print "KEEP: $borrower{'cardnumber'}\n";
         my %overlayer;
         $overlayer{'borrowernumber'} = $member->{'borrowernumber'};
         if ($borrower{borrowernotes} ne ""){
            if (($borrower{borrowernotes} eq $member->{borrowernotes}) or ($member->{borrowernotes} eq ($branch.": ".$borrower{borrowernotes}." -- "))){
               $overlayer{borrowernotes} = $branch.": ".$borrower{borrowernotes};
            }
            else{
               $overlayer{borrowernotes} = $branch.": ".$borrower{borrowernotes}." -- ".$member->{'borrowernotes'};
            }
         }
         if ($doo_eet && exists($overlayer{borrowernotes})){
            &ModMember(%overlayer);
         }
         $notes_merged++;
         $done=1;
      }
      if ($thisaction eq "NOTHING"){
         $ignored++;
         $done=1;
      }
      if (!$done){
         #Run in circles, scream, and shout; we should never get here.
         print $err "UNCLEAR WHAT TO DO:\n";
         print $err Dumper(%borrower);
         $unclear++;
      }
   }
}
close $in;
print "\n\n$i borrowers found.\n";
print "$attempted_write borrowers potentially written.\n$written new borrowers written.\n";
print "$attempted_overlay borrowers potentially overlaid by default.\n$def_overlaid borrowers overlaid by default action.\n";
print "$attempted_kept borrowers potentially kept by default.\n$def_kept borrowers kept by default action.\n";
print "$dupe_barcodes potential duplicate barcodes found.\n";
print "$dupe_names potential duplicate names found.\n";
print "$broken_records invalid records found.\n";
print "$unclear records where desirable action undefined or unclear.\n";
print "$other_problem records could not be added or modified by AddMember/ModifyMember.\n";
print "COMMAND OVERRIDES:\n";
foreach my $kee (keys %by_command){
   print "$kee:  $by_command{$kee}\n";
}
print "\nCOMMAND OVERRIDE EXECUTION:\n";
print "Overlaid:  $overlaid\n";
print "Data-only Overlaid: $do_overlaid\n";
print "Barcode-only Overlaid: $bo_overlaid\n";
print "Both-Kept: $both_used\n";
print "Kept with notes merge: $notes_merged\n";
print "Ignored: $ignored\n";
print "\n";
