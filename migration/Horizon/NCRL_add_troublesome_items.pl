#!/usr/bin/perl
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

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

my $csv;
my $map;
my %biblio_map;
my %branch_map;
my %shelfloc_map;
my %collcode_map;
my %itype_map;

open $map,'<','/home/load14/data/NCRL_golive_bib_map.csv';
$csv=Text::CSV_XS->new({binary => 1});
while (my $row=$csv->getline($map)) {
   my @data= @$row;
   $biblio_map{$data[0]} = $data[1];
}
close $map;
open $map,'<','/home/load14/data/NCRL_bibbranch_map.csv';
$csv=Text::CSV_XS->new();
while (my $row=$csv->getline($map)) {
   my @data= @$row;
   $branch_map{$data[0]} = $data[1];
}
close $map;
open $map,'<','/home/load14/data/NCRL_shelfloc_map.csv';
$csv=Text::CSV_XS->new();
while (my $row=$csv->getline($map)) {
   my @data= @$row;
   $shelfloc_map{$data[0]} = $data[1];
}
close $map;
open $map,'<','/home/load14/data/NCRL_collcode_map.csv';
$csv=Text::CSV_XS->new();
while (my $row=$csv->getline($map)) {
   my @data= @$row;
   $collcode_map{$data[0]} = $data[1];
}
close $map;
open $map,'<','/home/load14/data/NCRL_itemtype_map.csv';
$csv=Text::CSV_XS->new();
while (my $row=$csv->getline($map)) {
   my @data= @$row;
   $itype_map{$data[0]} = $data[1];
}
close $map;

my $csv2 = Text::CSV_XS->new({sep_char => "\|"});
open my $input_file,'<','/home/load14/dropbox/Go-Live/item2.dat';
RECORD:
while (my $line = $csv2->getline($input_file)){
   last RECORD if ($debug and $i > 0);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;
   $debug and print $data[0], $biblio_map{$data[0]};
   if (!$biblio_map{$data[0]}) {
      print "Biblio not found!\n";
      $problem++;
      next RECORD;
   }
   my %item;
   $item{cn_source}        = 'ddc';
   $item{barcode}          = $data[1];
   $item{itemcallnumber}   = $data[3];
   $item{copynumber}       = $data[4];
   $item{itemnotes}        = $data[8];
   $item{itemnotes}       .= '| ' . $data[14];
   $item{itemnotes}        =~ s/^\| //;
   $item{paidfor}          = $data[9];
   $item{price}            = $data[13];
   $item{replacementprice} = $data[13];
   $item{issues}           = $data[15];
   $item{booksellerid}     = $data[16];
   $item{dateaccessioned}  = _process_date($data[5]) || '';
   $item{datelastseen}     = _process_date($data[6]) || '';

   $item{homebranch}       = $branch_map{$data[11]} || $data[11];
   $item{holdingbranch}    = $branch_map{$data[11]} || $data[11];
   $item{location}         = $shelfloc_map{ uc $data[11]} || uc $data[11];
   if ($item{location} eq 'NULL') {
      delete $item{location};
   }

   $item{itype}            = $itype_map{$data[2]} || $data[2];
   $item{ccode}            = $collcode_map{$data[2]} || $data[2];

   foreach my $kee (keys %item) {
      if ($item{$kee} eq '') {
         delete $item{$kee};
      }
   }

   $debug and print "BIBLIO: $biblio_map{$data[0]}\n";
   $debug and print Dumper(%item);

   if ($doo_eet) {
      my ($thisbib,$thisbibitem,$thisitem) = C4::Items::AddItem (\%item,$biblio_map{$data[0]});
      if (!$thisitem) {
         print "problem adding item!\n";
         $problem++;
         next RECORD;
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

exit;

sub _process_date {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq q{};
   my ($month,$day,$year) = split /\-/,$datein;
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}

