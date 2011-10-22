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
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $infile_name="";
GetOptions(
    'in=s'          =? \$infile_name,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

my $written=0;
my $dbh=C4::Context->dbh();
my $query = 'select itemnumber from items where barcode=?;';
my $sth=$dbh->prepare($query);
my $csv = Text::CSV->new();
open my $in,"<",$infile_name;
my $headerline = $csv->getline($in);
my @fields = @$headerline;
while (my $row =$csv->getline($in)){
   my $data = @$row;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $sth->execute($data[0]);
   my $record=$sth->fetchrow_hashref();
   my $itm = $record->{'itemnumber'};
   $debug and print "\nItem:  $itm\n";
   while my $j (1..scalar(@fields)-1){
      if $data[$j]{
         my $variable_to_change = $fields[$j];
         my $new_value = $data[$j];
         $debug and print "Value: $variable_to_change => $new_value\n";  
         if ($doo_eet){
            C4::Items::ModItem({$variable_to_change=>$new_value},
                               undef,
                               $itm);
         }
         $written++;
      }
   }
}

close $in;
print "\n\n$i items found. $written fields modified.\n";
