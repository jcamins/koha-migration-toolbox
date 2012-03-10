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
# EXPECTS:
#   -Transaction log file with CV and EV transactions from Symphony
#   -Item type/duration maps for calculating due date
#   -Default number of days to calculate due date
#
# DOES:
#   -creates old_issues entries, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of CV/EV transactions found
#   -count of added transactions 
#   -what would be done, if --debug is set

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use Date::Calc qw(Add_Delta_Days);
use C4::Context;
use C4::Members;
use C4::Items;

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
my $days           = 0;
my @typedays;

GetOptions(
    'in=s'     => \$input_filename,
    'type=s'   => \@typedays,
    'days=i'   => \$days,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

for my $var ($days) {
   croak ("You're missing something") if !$var;
}

my %loan_period_map;
foreach my $typeday (@typedays) {
   my ($type,$period) = split /:/,$typeday;
   $loan_period_map{$type} = $period;
}

my %charges;
my $no_charge_returns = 0;
my $no_borrower       = 0;
my $no_item           = 0;
my $bad_command       = 0;
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO old_issues (borrowernumber,itemnumber,date_due,branchcode,issuedate,returndate)
                         VALUES (?,?,?,?,?,?)");
open my $input_file,'<',$input_filename;
LINE:
while (my $line=readline($input_file)) {
   last LINE if ($debug and $written > 10);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $this_command = substr($line,25,2);
   my ($this_item)  = $line =~ /\^NQ(.+?)\^/;
   #$debug and print "Command: $this_command\n";
   #$debug and print "Item: $this_item\n";
   my $item = GetItem(undef,$this_item);
   if (!$item->{itemnumber}) {
      $no_item++;
      next LINE;
   }
   my $this_date     = _process_date(substr($line,1,8));
   my $this_date_due = _calc_due_date($this_date,$item->{itype});

   if ($this_command eq "CV") {    # Charge Item Part B transaction
      my ($this_borrower) = $line =~ /\^UO(.+?)\^/;
      if (exists $charges{$this_item}) {
         print "Checkout for item already checked out! $this_date - $this_item - $this_borrower\n";
         print Dumper($charges{$this_item});
         $problem++;
         next LINE;
      }
      $charges{$this_item}{date}     = $this_date;
      $charges{$this_item}{date_due} = $this_date_due;
      $charges{$this_item}{borrower} = $this_borrower;
 #     if ($debug) {
 #        print Dumper(%charges);
 #        die;
 #     }
      next LINE;
   }
   elsif ($this_command eq "EV") {  # Discharge Item transaction
      if (!exists $charges{$this_item}) {
         $no_charge_returns++; 
         next LINE;
      }
      my $borrower = GetMember( 'cardnumber' => $charges{$this_item}{borrower} );
      if (!$borrower) {
         $no_borrower++;
         $debug and print "Bad Borrower: $charges{$this_item}{borrower}\n";
         delete $charges{$this_item};
         next LINE;
      }
      $debug and print "Adding Charge: Borrower $borrower->{borrowernumber} Item $item->{itemnumber} ";
      $debug and print "Out: $charges{$this_item}{date} Due: $charges{$this_item}{date_due} In: $this_date\n";
      if ($doo_eet) {
         $sth->execute( $borrower->{borrowernumber}, $item->{itemnumber},        $charges{$this_item}{date_due}, 
                        $item->{homebranch},         $charges{$this_item}{date}, $this_date );
      }
      $written++;
      delete $charges{$this_item};
      next LINE;
   }
   else {
      $bad_command++;
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$no_item records found where item is no longer defined.
$no_borrower records found where borrower is not defined.
$no_charge_returns records were returns where no checkout was present.
$bad_command records contained bad command codes. 
$problem records not loaded due to other problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;

sub _process_date {
   my $datein = shift;
   #$debug and print "_process_date date in: $datein\n";
   my $year  = substr($datein,0,4);
   my $month = substr($datein,4,2);
   my $day   = substr($datein,6,2);
   return sprintf "%d-%02d-%02d",$year,$month,$day;
}

sub _calc_due_date {
   my $datein                         = shift;
   my $type                           = shift;
   my ($year,$month,$day)             = split /\-/,$datein;
   my $days_to_use = $loan_period_map{$type} || $days;
   my ($year_out,$month_out,$day_out) = Add_Delta_Days($year,$month,$day,$days_to_use);
   return sprintf "%d-%02d-%02d",$year_out,$month_out,$day_out;
}
