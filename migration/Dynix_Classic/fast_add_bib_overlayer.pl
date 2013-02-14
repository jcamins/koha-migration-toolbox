#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -DRB
# 
# Modification log: (initial and date)
#
#---------------------------------

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use MARC::Charset;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;
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
my $nobib   = 0;

my $input_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');
my $dbh=C4::Context->dbh();
my $sth=$dbh->prepare("SELECT biblionumber FROM items WHERE barcode = ?");
my $csv=Text::CSV_XS->new({binary => 1});
open my $input_file,'<',$input_filename;
LINE:
while (my $line=$csv->getline($input_file)) {
   last LINE if ($debug && $written > 3000);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;
   my $rec;
   eval{ $rec = MARC::Record::new_from_usmarc($data[1]);};
   if ($@){
      print "\n Error in biblio for item $data[0]\n";
      next LINE;
   }
   $sth->execute($data[0]);
   my $item = $sth->fetchrow_hashref();
   if (!$item->{biblionumber}) {
     $nobib++; 
     next LINE;
   }
   $debug and print "item $data[0] biblio $item->{biblionumber} new marc:\n";
#   $debug and print $rec->as_formatted();
   if ($doo_eet) {
      C4::Biblio::ModBiblio($rec,$item->{biblionumber});
   }
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$nobib records not found.
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
