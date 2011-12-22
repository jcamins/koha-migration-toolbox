#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -Patron responsibility data, CSV, in THIS order:
#      patron barcode, guarantor barcode
#
# DOES:
#   -inserts guarantor data, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -problem records
#   -count of lines read
#   -count of fines inserted
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

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;

my $input_filename = "";

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename) {
   croak ("You're missing something") unless $var ne $NULL_STRING;
}

my $csv     = Text::CSV_XS->new();
my $dbh     = C4::Context->dbh();
my $written = 0;
my $problem = 0;

my $borrower_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber = ?");
my $insert_sth   = $dbh->prepare("UPDATE borrowers SET guarantorid = ? WHERE cardnumber = ?");

open my $input_file,'<',$input_filename;

LINE:
while (my $line=$csv->getline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;

   $borrower_sth->execute($data[1]);
   my $this_borrower= $borrower_sth->fetchrow_hashref();
   if ($this_borrower) {
      $debug and print "B: $data[1] ($this_borrower->{borrowernumber})   G:$data[0]\n";
      if ($doo_eet){
         $insert_sth->execute( $this_borrower->{borrowernumber} ,$data[0]);
      }
      $written++;
   }
   else {
      print "Problem record:\n";
      print "B: $data[1]  G:$data[0]\n";
      $problem++;
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;
