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
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $create = 0;
my $patron_cat_mapfile;
my %patron_cat_map;
my $toss_profile_string = "";
my %profiles_to_toss;
my $upcase_name=0;

GetOptions(
    'in=s'            => \$infile_name,
    'out=s'           => \$outfile_name,
    'toss-profiles=s' => \$toss_profile_string,
    'patron-cat=s'    => \$patron_cat_mapfile,
    'upcase_name'     => \$upcase_name,
    'debug'           => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

if ($toss_profile_string){
   foreach my $kee (split(/,/,$toss_profile_string)){
      $profiles_to_toss{$kee} = 1;
   }
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

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my @borrowers;
my $addr1;
my $addr2;
my $addr3;
my $note;
my %thisborrower = ();
my $toss_this_borrower;
my $borrowers_tossed;
my %headerkees;
my %categories;

while (my $line = readline($in)) {
   last if ($debug && $j>9);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($line =~ /DOCUMENT BOUNDARY/){
      if (%thisborrower && !$toss_this_borrower){
         $j++;
         $categories{$thisborrower{'categorycode'}}++;
         push @borrowers,{%thisborrower};
         foreach my $kee ( sort keys %thisborrower){
            $headerkees{$kee} = 1;
         }
      }
      print Dumper(%thisborrower) if ($thisborrower{'cardnumber'} eq "3755");
      $borrowers_tossed++ if ($toss_this_borrower);
      $note = 0;
      $addr1 = 0;
      $addr2 = 0;
      $addr3 = 0;
      $toss_this_borrower=0;
      %thisborrower=();
      $thisborrower{'contactnote'} = "";
      next;
   }
   next if ($toss_this_borrower);
   $debug and print $line."\n";
   $line =~ /^\.([\w\/]+)\./;
   my $thistag = $1;
   $line =~ /\|a(.*)$/;
   my $content = $1;
   $debug and print "$thistag ~~ $content ~~\n";
   
   $note = 0 if ($thistag);
   if (($thistag eq "NOTE") or ($thistag eq "COMMENT") or ($thistag eq "WEBCATPREF")){
      $thisborrower{'contactnote'} .= " -- " if $thisborrower{'contactnote'};
      $thisborrower{'contactnote'} .= $content." ";
      $note = 1;
      next;
   }
   if (($thistag eq "") && $note){
      $thisborrower{'contactnote'} .= $line." ";
      next;
   }

   if ($thistag eq "USER_NAME"){
      $content =~ s/\$/ /g;
      $content =~ s/#/ /g;
      $content =~ s/\*/ /g;
      $content =~ s/  / /g;
      $content =~ s/  / /g;
      $content =~ s/^ //g;
      $content =~ s/ $//g;
      if ($content =~ /name_not_yet_supplied/i){
         $toss_this_borrower=1;
         next;
      }
      if ($content =~ /([\w\s]+),(.*)/){
         $thisborrower{'surname'} = $1;
         $thisborrower{'firstname'} = $2;
      }
      elsif ($content =~/(\w+) (.*)/){
         $thisborrower{'surname'} = $1;
         $thisborrower{'firstname'} = $2;
      }
      else {
         $thisborrower{'surname'} = $content;
         $thisborrower{'firstname'} = "";
      }
      $thisborrower{'firstname'} =~ s/^ //g;
      if ($upcase_name){
         $thisborrower{'surname'} = uc($thisborrower{'surname'});
         $thisborrower{'firstname'} = uc($thisborrower{'firstname'});
      }
      next;
   }
   
   if ($thistag eq "USER_PROFILE"){
      if (exists $profiles_to_toss{$content}){
         $debug and warn "Tossing a borrower for profile $content.";
         $toss_this_borrower=1;
         next;
      }
      if (exists $patron_cat_map{$content}){
         $debug and warn "Swapping cat $content to $patron_cat_map{$content}.";
         $thisborrower{'categorycode'} = $patron_cat_map{$content};
         next;
      }
      $thisborrower{'categorycode'} = $content;
      next;
   } 

   $thisborrower{'cardnumber'} = $content if ($thistag eq "USER_ID");
   $thisborrower{'userid'} = $content if ($thistag eq "USER_ID");
   $thisborrower{'password'} = $content if ($thistag eq "USER_PIN");
   $thisborrower{'branchcode'} = $content if ($thistag eq "USER_LIBRARY");
   $thisborrower{'debarred'} = 1 if (($thistag eq "USER_STATUS") && ($content eq "BARRED"));
   $thisborrower{'dateenrolled'} = _process_date($content) if ($thistag eq "USER_PRIV_GRANTED");
   $thisborrower{'dateexpiry'} = _process_date($content) if ($thistag eq "USER_PRIV_EXPIRES");
   $thisborrower{'dateofbirth'} = _process_date($content) if ($thistag eq "USER_BIRTH_DATE");

   if ($thistag eq "USER_ADDR1_BEGIN"){
      $addr1=1;
      next;
   }
   if ($thistag eq "USER_ADDR1_END"){
      $addr1=0;
      next;
   }
   if ($thistag eq "USER_ADDR2_BEGIN"){
      $addr2=1;
      next;
   }
   if ($thistag eq "USER_ADDR2_END"){
      $addr2=0;
      next;
   }
   if ($thistag eq "USER_ADDR3_BEGIN"){
      $addr3=1;
      next;
   }
   if ($thistag eq "USER_ADDR3_END"){
      $addr3=0;
      next;
   }
   if ($addr1){
      $debug and print $line."\n" if ($thistag eq "");
      $thisborrower{'city'} = $content if ($thistag eq "CITY/STATE");
      $thisborrower{'zipcode'} = $content if ($thistag eq "ZIP");
      $thisborrower{'address'} = $content if ($thistag eq "STREET");
      $thisborrower{'address2'} = $content if ($thistag eq "ATTN");
      $thisborrower{'fax'} = $content if ($thistag eq "FAX");
      if ($thistag eq "EMAIL"){
         if ($content =~ /@/){
            $thisborrower{'email'} = $content;
            next;
         }
         $thisborrower{'contactnote'} .= " -- " if $thisborrower{'contactnote'};
         $thisborrower{'contactnote'} .= $content." ";
      }
      next;
   }
   if ($addr2){
      $debug and print $line."\n" if ($thistag eq "");
      next;
   }
   if ($addr3){
      $debug and print $line."\n" if ($thistag eq "");
      next;
   }
   $debug and print $line if ($thistag eq "");
}
if (%thisborrower && !$toss_this_borrower){
   $j++;
   $categories{$thisborrower{'categorycode'}}++;
   push @borrowers,{%thisborrower};
   foreach my $kee ( sort keys %thisborrower){
      $headerkees{$kee} = 1;
   }
}


print "\n\n$i lines read.\n$j borrowers found.\n$borrowers_tossed borrowers tossed out.\n";
open my $sql,">","patron_codes.sql";
print "CATEGORY COUNTS\n";
foreach my $kee (sort keys %categories){
   print "$kee: $categories{$kee}\n";
   print {$sql} "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}
close $sql;

open my $out,">$outfile_name";
foreach my $kee (sort keys %headerkees){
   print $out $kee.",";
}
print $out "\n";
for (my $j=0;$j<scalar(@borrowers);$j++){
   foreach my $kee (sort keys %headerkees){
      $borrowers[$j]{$kee} =~ s/\"/'/g;
      if ($borrowers[$j]{$kee} =~ /,/){
         print $out '"'.$borrowers[$j]{$kee}.'",';
         next;
      }
      else{
         if ($borrowers[$j]{$kee}){
            print $out $borrowers[$j]{$kee};
         }
         print $out ",";
      }
   }
   print $out "\n";
}
close $in;
close $out;
exit;

sub _process_date {
    my ($date_in) = @_;
    return "" if ($date_in eq "NEVER");
    my $year = substr($date_in,0,4);
    my $month = substr($date_in,4,2);
    my $day = substr($date_in,6,2);
    return sprintf "%d-%02d-%02d",$year,$month,$day;
}
