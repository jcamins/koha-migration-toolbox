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
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;
my $j=0;

my $infile_name="";
GetOptions(
    'in=s'          => \$infile_name,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

my $dbh=C4::Context->dbh();
my $query_stem = 'select itemnumber from items where ';
my $csv = Text::CSV->new();
open my $in,"<",$infile_name;
my $headerline = $csv->getline($in);
my @fields = ('branchcode','itype','location','ccode','itemcallnumber');
my @op = ('=','=','=','=','LIKE');
while (my $row =$csv->getline($in)){
   my $data = @$row;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   my @query_elements; 
OLD_FIELD_VALUE:
   for my $t(0..4){
      $data[$t] =~ s/^\s//;
      $data[$t] =~ s/\s$//;
      next OLD_FIELD_VALUE if ($t eq '*'); 
      if ($t eq q{}){
         push @query_elements,"($fields[$t]='' OR $fields[$t] IS NULL)";
      }
      else{
         push @query_elements,"$fields[$t] $op[$t] '$data[$t]'";
      }
   }
   my $query=$query_stem.join(' AND ',@query_elements);
   $debug and print "\n$query\n";

}




#   my $record=$sth->fetchrow_hashref();
#   my $itm = $record->{'itemnumber'};
#   $debug and print "\nItem:  $itm\n";
#   while my $j (1..scalar(@fields)-1){
#      if $data[$j]{
#         my $variable_to_change = $fields[$j];
#         my $new_value = $data[$j];
#         $debug and print "Value: $variable_to_change => $new_value\n";  
#         if ($doo_eet){
#            C4::Items::ModItem({$variable_to_change=>$new_value},
#                               undef,
#                               $itm);

close $in;
print "\n\n$i items found. $j fields modified.\n";
