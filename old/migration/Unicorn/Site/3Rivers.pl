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
use Text::CSV;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;

GetOptions(
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

#if (($branch eq '')){
#  print "Something's missing.\n";
#  exit;
#}

my $dbh=C4::Context->dbh();
my $i;
my $sth;
my $upd_sth;
my $dropped;
my $modified;

# 
# Dealing with LAFAYETTE Y-ADULT 
#
print "\n\nDealing with LAFAYETTE Y-ADULT\n";
$i=0;
$sth=$dbh->prepare("SELECT itemnumber FROM items WHERE homebranch='LAFAYETTE' and location='Y-ADULT'");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "setting JUVENILE on item $rec->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location      => "JUVENILE",
                            },undef,$rec->{'itemnumber'});
   }
}
print "\n\n$i Records modified.\n";

# 
# Dealing with GILCHIRIST Y-ADULT 
#
print "\n\nDealing with GILCHRIST Y-ADULT\n";
$i=0;
$sth=$dbh->prepare("SELECT itemnumber FROM items WHERE homebranch='GILCHRIST' and location='Y-ADULT'");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "setting ADULT on item $rec->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location      => "ADULT",
                            },undef,$rec->{'itemnumber'});
   }
}
print "\n\n$i Records modified.\n";

# 
# Dealing with DIXIE LARGEPRINT,MULTIMEDIA,Y-ADULT
#
print "\n\nDealing with DIXIE LARGEPRINT,MULTIMEDIA,Y-ADULT\n";
$i=0;
$sth=$dbh->prepare("SELECT itemnumber FROM items WHERE homebranch='DIXIE' and location in ('LARGEPRINT','MULTIMEDIA','Y-ADULT')");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "setting ADULT on item $rec->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location      => "ADULT",
                            },undef,$rec->{'itemnumber'});
   }
}
print "\n\n$i Records modified.\n";

# 
# Dealing with VIDEO type
#
print "\n\nDealing with VIDEO itype.\n";
$i=0;
$sth=$dbh->prepare("SELECT itemnumber,itype,location FROM items WHERE itype='VIDEO'");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($rec->{'location'} eq "VHS"){
      $debug and print "setting VHS on item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         C4::Items::ModItem({itype         => "VHS",
                             location      => "VHS",
                            },undef,$rec->{'itemnumber'});
      }
   }
   elsif ($rec->{'location'} eq "DVD"){
      $debug and print "setting DVD on item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         C4::Items::ModItem({itype         => "DVD",
                             location      => "VHS",
                            },undef,$rec->{'itemnumber'});
      }
   }
   else{
      $debug and print "setting UNKNOWN on item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         C4::Items::ModItem({itype         => "UNKNOWN", 
                            },undef,$rec->{'itemnumber'});
      }
   }
}
print "\n\n$i item records modified.\n";


#
# Dealing with CDR type
#
print "\n\nDealing with CDR itype.\n";
$i=0;
$dropped=0;
$modified=0;
$sth=$dbh->prepare("SELECT biblionumber,itemnumber,homebranch FROM items WHERE itype='CDR'");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($rec->{'homebranch'} eq "GILCHRIST"){
      $debug and print "setting SOFTWARE on item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         C4::Items::ModItem({itype         => "SOFTWARE",
                            },undef,$rec->{'itemnumber'});
      }
      $modified++;
   }
   else {
      $debug and print "DROPPING item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         my $error = &DelItemCheck($dbh,$rec->{'biblionumber'},$rec->{'itemnumber'});
         if ($error eq "1"){
            #NOP
         }
         else{
            print "Error deleting item $rec->{'itemnumber'}: $error\n";
         }
      }
      $dropped++;
   }
}
print "\n\n$i items found.\n$modified items modified.\n$dropped items dropped.\n";

#
# Dealing with biblio CDR,VIDEOs
#
print "\n\nDealing with biblio CDR,VIDEOs\n";
$i=0;
$sth=$dbh->prepare("SELECT biblioitems.biblionumber AS biblionumber,marc,frameworkcode from biblioitems 
                    JOIN biblio USING (biblionumber) WHERE itemtype IN ('CDR','VIDEO')");
$sth->execute();
$upd_sth = $dbh->prepare("UPDATE biblioitems SET itemtype=? WHERE biblionumber=?");
while (my $thisrec=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my $rec = MARC::Record::new_from_usmarc( $thisrec->{'marc'});
   foreach my $dump ($rec->field("942")){
      $debug and print "Biblio $thisrec->{'biblionumber'}: ";
      $rec->delete_field($dump);
   }
   my $val = $rec->subfield("952","y");
   if ($val){
      $debug and print "New: $val";
      my $field=MARC::Field->new("942"," "," ","c" => $val);
      $rec->insert_grouped_field($field);
      if ($doo_eet){
         $upd_sth->execute($val,$thisrec->{'biblionumber'});
      }
   }
   else{
      if ($doo_eet){
         $upd_sth->execute(undef,$thisrec->{'biblionumber'});
      }
   } 
   if ($doo_eet){
      C4::Biblio::ModBiblioMarc($rec,$thisrec->{'biblionumber'}, $thisrec->{'frameworkcode'});
   }
   $debug and print "\n";
}
print "\n\n$i records found and modified.\n";

#
# Dealing with MAGAZINE type
#
print "\n\nDealing with MAGAZINE itype.\n";
$i=0;
$dropped=0;
$modified=0;
$sth=$dbh->prepare("SELECT biblionumber,itemnumber,homebranch FROM items WHERE itype='MAGAZINE'");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($rec->{'homebranch'} eq "DIXIE"){
      $debug and print "setting BOOK on item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         C4::Items::ModItem({itype         => "BOOK",
                             location      => "ADULT",
                            },undef,$rec->{'itemnumber'});
      }
      $modified++;
   }
   else {
      $debug and print "DROPPING item $rec->{'itemnumber'}\n";
      if ($doo_eet){
         my $error = &DelItemCheck($dbh,$rec->{'biblionumber'},$rec->{'itemnumber'});
         if ($error eq "1"){
            #NOP
         }
         else{
            print "Error deleting item $rec->{'itemnumber'}: $error\n";
         }
      }
      $dropped++;
   }
}
print "\n\n$i items found.\n$modified items modified.\n$dropped items dropped.\n";

#
# Dealing with SUWANNEE location 
#
print "\n\nDealing with SUWANNEE location.\n";
$i=0;
$dropped=0;
$sth=$dbh->prepare("SELECT biblionumber,itemnumber FROM items WHERE location='SUWANNEE'");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "DROPPING item $rec->{'itemnumber'}\n";
   if ($doo_eet){
      my $error = &DelItemCheck($dbh,$rec->{'biblionumber'},$rec->{'itemnumber'});
      if ($error eq "1"){
         #NOP
      }
      else{
         print "Error deleting item $rec->{'itemnumber'}: $error\n";
      }
   }
   $dropped++;
}
print "\n\n$i items found.\n$dropped items dropped.\n";

#
# Dealing with blank location 
#
print "\n\nDealing with blank location.\n";
$i=0;
$dropped=0;
$sth=$dbh->prepare("SELECT biblionumber,itemnumber FROM items WHERE location=''");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $debug and print "setting NULL on item $rec->{'itemnumber'}\n";
   if ($doo_eet){
      C4::Items::ModItem({location      => undef,
                         },undef,$rec->{'itemnumber'});
   }
}
print "\n\n$i items found and edited.\n";

