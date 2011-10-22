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
#   -Borrowers with Outstanding Items report from TLC, saved as CSV
#
# DOES:
#   -Adds checkout records to issues table, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be added, if --debut is set
#   -count of lines read
#   -count of checkouts added
#   -problem records
#   -count of problems.

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

local    $OUTPUT_AUTOFLUSH = 1;
Readonly my $NULL_STRING => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;

my $input_filename          = $NULL_STRING;


GetOptions(
    'in=s'               => \$input_filename,
    'debug'              => \$debug,
    'update'             => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something.") unless $var ne $NULL_STRING;
}

my $csv = Text::CSV_XS->new();

my $written                = 0;
my $problem                = 0;
my $grab_borrower          = 0;
my $current_borrowerbar    = $NULL_STRING;
my $current_borrowernumber = $NULL_STRING;

my $dbh          = C4::Context->dbh();
my $borrower_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
my $insert_sth   = $dbh->prepare("INSERT INTO issues 
                                  (borrowernumber, itemnumber, date_due, issuedate, branchcode) 
                                  VALUES (?, ?, ?, ?, ?)");

open my $input_file,'<',$input_filename;

LINE:
while (my $line=$csv->getline($input_file)){
   $debug and last LINE if ($i > 10);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;

   if ($data[7] =~ m/\d/) {
      for my $j (1..3) {
         my $dummy = readline($input_file);
         $i++;
      }
      next LINE;
   }

   if ($data[5] eq "Borrower ID") {
      $grab_borrower=1;
      next LINE;
   }

   if ($grab_borrower) {
      $current_borrowerbar = $data[5];
      $current_borrowernumber = undef;
      my $member = GetMemberDetails(undef,$current_borrowerbar);
      if ($member) {
         $current_borrowernumber = $member->{borrowernumber};
      }
      $grab_borrower = 0;
      next LINE;
   }

   if ($data[7] =~ m/\w/){
      my $this_itembar    = $data[1];
      my $this_itemnumber = undef;
      my $this_itembranch = undef;
      my $item = GetItem(undef,$this_itembar);
      if ($item) {
         $this_itemnumber = $item->{itemnumber};
         $this_itembranch = $item->{homebranch};
      }

      my $this_datedue    = _process_date($data[4]);
      my $this_dateout    = _process_date($data[5]);

      if ($current_borrowernumber && $this_itemnumber){
         $debug and print "B:$current_borrowerbar ($current_borrowernumber) I:$this_itembar ($this_itemnumber) ";
         $debug and print "Br: $this_itembranch O:$this_dateout D:$this_datedue\n";
         if ($doo_eet) {
            $insert_sth->execute($current_borrowernumber, $this_itemnumber, $this_datedue, $this_dateout, $this_itembranch);
            ModItem({itemlost         => 0,
                     datelastborrowed => $this_dateout,
                     datelastseen     => $this_dateout,
                     onloan           => $this_datedue,
                    },undef,$this_itemnumber);

         }
         $written++;
      }
      elsif (!$current_borrowernumber) {
         print "\nProblem Record:\n";
         print "B:$current_borrowerbar () I:$this_itembar ($this_itemnumber) ";
         print "Br: $this_itembranch O:$this_dateout D:$this_datedue\n";
         $problem++;
      }
      else {
         print "\nProblem Record:\n";
         print "B:$current_borrowerbar ($current_borrowernumber) I:$this_itembar () ";
         print "Br: $this_itembranch O:$this_dateout D:$this_datedue\n";
         $problem++;
      }
      next LINE;
   }
}
print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;

sub _process_date {
   my ($date) = @ARG;
   return if $date eq $NULL_STRING;
   my ($month,$day,$year) = split '/', $date;
   if ($year <= 12) {
      $year += 2000;
   }
   if ($year <= 99) {
      $year += 1900;
   }
   return sprintf "%d-%02d-%02d",$year,$month,$day;
}


