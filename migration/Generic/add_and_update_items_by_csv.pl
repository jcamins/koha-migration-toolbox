#!/usr/bin/perl
#---------------------------------
# Copyright 2013 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -input CSV in this form:
#
# DOES:
#   -creates or updates items, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of items added
#   -count of items modified
#   -details of what will be changed, if --debug is set

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use C4::Context;
use C4::Branch;
use C4::Items;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};
my $start_time             = time();

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $modified = 0;
my $problem = 0;

my $input_filename       = $NULL_STRING;
my $csv_delim            = 'comma';
my $add                  = 0;
my $modify               = 0;
my @datamap_filenames;
my %datamap;

GetOptions(
    'in=s'        => \$input_filename,
    'delimiter=s' => \$csv_delim,
    'add'         => \$add,
    'modify'      => \$modify,
    'map=s'       => \@datamap_filenames,
    'debug'       => \$debug,
    'update'      => \$doo_eet,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if (!$add and !$modify) {
   croak ("Neither --add or --modify was specified. Why do anything?");
}

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                );

foreach my $map (@datamap_filenames) {
   my ($mapsub,$map_filename) = split (/:/,$map);
   my $csv = Text::CSV_XS->new( {binary=>1});
   say "Reading $mapsub map";
   my $j = 0;
   open my $mapfile,'<',$map_filename;
   while (my $row = $csv->getline($mapfile)) {
      $j++;
      print '.'    unless ($j % 10);
      print "\r$j" unless ($j % 100);
      my @data = @$row;
      $datamap{$mapsub}{$data[0]} = $data[1];
   }
   close $mapfile;
   print "\n$j lines read.\n";
}

my $csv=Text::CSV_XS->new({ binary => 1 , sep_char => $delimiter{$csv_delim} });
open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file));
$debug and print Dumper($csv->column_names());

my @item_fields = qw /booksellerid     ccode                cn_source      copynumber   
                      damaged          dateaccessioned      enumchron      holdingbranch
                      homebranch       issues               itemcallnumber itemlosti
                      itemnotes        itype                location       materials
                      notforloan       paidfor              price          renewals
                      replacementprice replacementpricedate reserves       restricted
                      stack            uri                  wthdrawn       datelastborrowed
                      datelastseen
                     /;

RECORD:
while (my $record=$csv->getline_hr($input_file)){
   last RECORD if ($debug and ($written>0 || $modified>0));
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);

   for my $tag (keys %$record) {
      my $oldval = $record->{$tag};
      if ($datamap{$tag}{$oldval}) {
         $record->{$tag} = $datamap{$tag}{$oldval};
         if ($datamap{$tag}{$oldval} eq 'NULL') {
            delete $record->{$tag};
         }
      }
   }

   my %item;
   my $barcode      = $record->{barcode};
   my $biblionumber = $record->{biblionumber};

   foreach my $tag (@item_fields) {
      if (exists $record->{$tag} and $record->{$tag} ne $NULL_STRING) {
         $item{$tag} = $record->{$tag}; 
      }
   }
   my $itemnumber = GetItemnumberFromBarcode($barcode);
   if (!$itemnumber) {     # new item
      if ($add) {          # don't do it if we're not adding!
         $item{barcode} = $barcode;
         $debug and say "New item $barcode for $biblionumber:";
         $debug and print Dumper(%item);
         if ($doo_eet) {
            C4::Items::AddItem(\%item,$biblionumber);
         }
         $written++;
      }
      next RECORD;
   }
   else {                 # item already exists;
      if ($modify) {      # don't do it if we're not modifying!
         delete $item{datelastborrowed};
         delete $item{datelastseen};
         $debug and say "Modified item $barcode, Bib $biblionumber, Item $itemnumber:";
         $debug and print Dumper(%item);
         if ($doo_eet) {
            C4::Items::ModItem(\%item,undef,$itemnumber);
         }
         $modified++;
      }
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$written items written.
$modified items edited.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
