#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# 
# Modification log: (initial and date)
#
#---------------------------------
#
use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use C4::Context;
use C4::Items;
use C4::Members;
use Date::Calc qw(Add_Delta_Days);

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = $NULL_STRING;
my $borrower_column = $NULL_STRING;
my $item_column     = $NULL_STRING;
my $bar_prefix      = $NULL_STRING;
my $dateout_column  = $NULL_STRING;
my $branchcode      = $NULL_STRING;
my $return_column   = $NULL_STRING;
my $due_column      = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'borr=s'   => \$borrower_column,
    'item=s'   => \$item_column,
    'prefix=s' => \$bar_prefix,
    'dateout=s' => \$dateout_column,
    'branch=s'  => \$branchcode,
    'return=s'  => \$return_column,
    'due=s'     => \$due_column,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename,$borrower_column,$item_column,$dateout_column,$branchcode,$bar_prefix) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $csv=Text::CSV_XS->new();
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("INSERT INTO issues 
                       (borrowernumber,itemnumber,date_due,branchcode,issuingbranch,issuedate) VALUES (?,?,?,?,?,?)");
my $old_sth=$dbh->prepare("INSERT INTO old_issues
                       (borrowernumber,itemnumber,date_due,branchcode,issuingbranch,issuedate,returndate) VALUES (?,?,?,?,?,?,?)");
open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file));
LINE:
while (my $line=$csv->getline_hr($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   my $itembar= $bar_prefix.'-'.$line->{$item_column};
   my $itemnumber = GetItemnumberFromBarcode($itembar);

   my $curbar = $line->{$borrower_column};
   my $prefixlen = length($bar_prefix);
   if ( length($curbar) <= (8-$prefixlen)) {
      my $fixlen = 8 - $prefixlen;
      while (length($curbar) < $fixlen) {
         $curbar = '0'.$curbar;
      }
   }
   my $borrower_bar=$bar_prefix.$curbar;
   my $borrower = GetMemberDetails(undef,$borrower_bar);


   my $date_out = $line->{$dateout_column};
 
   my $date_due = $NULL_STRING; 
   if ($due_column eq $NULL_STRING) {
      my ($year_out,$month_out,$day_out) = split /-/,$date_out;
      my ($year_due,$month_due,$day_due) = Add_Delta_Days($year_out,$month_out,$day_out,14); 
      $date_due = sprintf "%d-%02d-%02d",$year_due,$month_due,$day_due;
   }
   else {
      $date_due = $line->{$due_column};
   }
   
   my $return_date = $NULL_STRING;
   if ($return_column ne $NULL_STRING) {
      $return_date = $line->{$return_column};
   } 

   if (!$itemnumber || !$borrower->{borrowernumber}){
      $problem++;
      print "Problem:  ITEM: $itemnumber ($itembar)  Borr:$borrower->{borrowernumber} ($borrower_bar) RET: $return_date\n";
      next LINE;
   }

   if ($doo_eet) {
      if ($return_date eq $NULL_STRING){
         $sth->execute($borrower->{borrowernumber},$itemnumber,$date_due,$branchcode,$branchcode,$date_out);
      }
      else {
         $old_sth->execute($borrower->{borrowernumber},$itemnumber,$date_due,$branchcode,$branchcode,$date_out,$return_date);
      }
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
