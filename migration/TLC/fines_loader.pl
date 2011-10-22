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
#   -Outstanding Fines report from TLC, saved as CSV
#
# DOES:
#   -inserts fines into accountlines, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be inserted, if --debug is set
#   -count of lines read
#   -count of fines inserted
#   -problem records
#   -count of problems

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
use C4::Accounts;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

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
   croak ("You're missing something") unless $var ne $NULL_STRING;
}

my $csv = Text::CSV_XS->new();

my $written                = 0;
my $problem                = 0;
my $current_borrowerbar    = $NULL_STRING;
my $current_borrowernumber = $NULL_STRING;

my $dbh                = C4::Context->dbh();
my $insert_sth         = $dbh->prepare("INSERT INTO accountlines 
                                        (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding, itemnumber)
                                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)");
my $insert_sth_noitem  = $dbh->prepare("INSERT INTO accountlines 
                                        (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding)
                                        VALUES (?, ?, ?, ?, ?, ?, ?)");

open my $input_file,'<',$input_filename;

LINE:
while (my $line=$csv->getline($input_file)){
   $debug and last LINE if ($i > 10);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;

   if ($data[1] eq "Outstanding Fines") {
      for my $j (1..5) {
         my $dummy = readline($input_file);
         $i++;
      }
      next LINE;
   }

   if ($data[2] eq "Home Location:") {
      $current_borrowerbar = $data[1];
      $current_borrowernumber = undef;
      my $member = GetMemberDetails(undef,$current_borrowerbar);
      if ($member) {
         $current_borrowernumber = $member->{borrowernumber};
      }
      next LINE;
   }

   if ($data[2] =~ m/\w/){
      my $this_itembar    = $data[1];
      my $this_itemnumber = undef;
      my $item = GetItem(undef,$this_itembar);
      if ($item) {
         $this_itemnumber = $item->{itemnumber};
      }

      my $this_finedate    = _process_date($data[3]);
      my $this_finetype    = $data[2] eq 'OV' ? 'F'
                           : $data[2] eq 'L'  ? 'L'
                           :                    'M';

      my $this_description  = "Migrated from TLC-";
      $this_description    .= $data[2] eq 'OV' ? 'Overdue'
                            : $data[2] eq 'L'  ? 'Lost Item'
                            :                    'Miscellaneous';
      if (!$this_itemnumber){
         $this_description .= '--'.$this_itembar;
      }

      my $this_accountnumber = getnextacctno($current_borrowernumber);
      my $this_amount        = $data[5];

      if ($current_borrowernumber && $this_itemnumber){
         $debug and print "B:$current_borrowerbar ($current_borrowernumber) I:$this_itembar ($this_itemnumber) ";
         $debug and print "A:$this_accountnumber D:$this_finedate D:$this_description T:$this_finetype\n";
         if ($doo_eet) {
            $insert_sth->execute($current_borrowernumber,  $this_accountnumber,  $this_finedate,  $this_amount,  
                                 $this_description,        $this_finetype,      $this_amount,    $this_itemnumber);
         }
         $written++;
      }
      elsif ($current_borrowernumber && !$this_itemnumber) {
         $debug and print "B:$current_borrowerbar ($current_borrowernumber) I:$this_itembar () ";
         $debug and print "A:$this_accountnumber D:$this_finedate D:$this_description T:$this_finetype\n";
         if ($doo_eet) {
            $insert_sth_noitem->execute($current_borrowernumber,  $this_accountnumber,  $this_finedate,  $this_amount,  
                                        $this_description,        $this_finetype,      $this_amount);
         }
         $written++;
      }
      else {
         print "\nProblem Record:\n";
         print "B:$current_borrowerbar () I:$this_itembar () ";
         print "A:$this_accountnumber D:$this_finedate D:$this_description T:$this_finetype\n";
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


