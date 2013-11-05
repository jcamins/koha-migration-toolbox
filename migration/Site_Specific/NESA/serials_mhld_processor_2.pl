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

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use C4::Context;
use C4::Biblio;
use MARC::File::USMARC;
use MARC::File::XML;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;

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
my $biblio_map_filename = $NULL_STRING;
my %biblio_map;
my $location_map_filename = $NULL_STRING;
my %location_map;

GetOptions(
    'in=s'     => \$input_filename,
    'biblio_map=s' => \$biblio_map_filename,
    'location_map=s' => \$location_map_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename, $biblio_map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if ($location_map_filename ne $NULL_STRING) {
   print "Reading in location map file.\n";
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$location_map_filename;
   while (my $line = $csv->getline($mapfile)) {
      my @data = @$line;
      $location_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

print "Reading in biblio map file.\n";
if ($biblio_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$biblio_map_filename;
   while (my $line = $csv->getline($mapfile)) {
      my @data = @$line;
      $biblio_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my %touched = ();
my %locations_used = ();
my $stop_point = 0;
my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();
 
open my $output_file,'>','/home/load06/problems.txt';
my $dbh = C4::Context->dbh();
my $locations_count_sth = $dbh->prepare("SELECT DISTINCT location FROM items WHERE biblionumber = ?");

RECORD:
while() {
   last RECORD if ($debug && $stop_point);
   my $record;
   eval {$record = $batch->next();};
   if ($@) {
      say "Bogus record skipped.";
      $problem++;
      next RECORD;
   }
   last RECORD unless ($record);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

my $bib_id=$NULL_STRING;

FIELD035:
   foreach my $field ($record->field('035')) {
      my $data = $field->subfield('a');
      #$debug and say "DATA: $data";
      $bib_id = substr($data,7);
      $bib_id =~ s/ //g;
   }
   if ($bib_id eq $NULL_STRING) {
      say "Problem: bib number not found in MHLD.";
      $problem++;
      next RECORD;
   }
   my $biblio = GetMarcBiblio($biblio_map{$bib_id});
   if (!$biblio) {
      say "Problem: Biblio not found $bib_id.";
      $problem++;
      next RECORD;
   }
   #if ($biblio_map{$bib_id} != 34770) {
   #if ($i != 15) {
   #   next RECORD;
   #}

   if (!$touched{$biblio_map{$bib_id}}) {
      foreach my $tag ('852','853','863','866','867','868') {
         foreach my $field ($biblio->field($tag)) {
            $biblio->delete_field($field);
         }
      }
      $touched{$biblio_map{$bib_id}}=1;
   }

   $debug and say "MHLD:";
   $debug and print $record->as_formatted();
   $debug and say "";
   #$debug and print $biblio->as_formatted();
   $biblio->insert_fields_ordered($record->field('852'));
   $biblio->insert_fields_ordered($record->field('853'));
   $biblio->insert_fields_ordered($record->field('863'));
   #$biblio->insert_fields_ordered($record->field('866'));
   $biblio->insert_fields_ordered($record->field('867'));
   $biblio->insert_fields_ordered($record->field('868'));

   my $field852 = $record->field('852');
   my $location = $field852->subfield('b') || $NULL_STRING;
   if (defined $location_map{$location} ) {
      $location = $location_map{$location};
   }
   my $fld245 = $biblio->field('245');
   my $title = $fld245->as_string();
   if ($location eq $NULL_STRING ) {
      $locations_count_sth->execute($biblio_map{$bib_id});
      my $locations = $locations_count_sth->fetchall_arrayref;
      if (scalar @{$locations} eq 1) {
         my @locs = @$locations;
         my $location_to_use = lc @{$locs[0]}->[0];
         $location = $location_to_use;
      }
      else{
         print {$output_file} "866b BLANK: Biblio $biblio_map{$bib_id}: $title\n";
      }
   }
   if (($location ne 'ser') && ($location ne 'ref') && ($location ne 'micro') && ($location ne 'inact')) {                 #VMI
      print {$output_file} "866b $location: Biblio $biblio_map{$bib_id}: $title\n";
   }

   $locations_used{$location}++;
   my $holdings = $NULL_STRING,
#   my $holdings = sprintf "%s - %s - %s:\n",$field852->subfield('a') || $NULL_STRING,
#                                            $field852->subfield('h') || $NULL_STRING,
#                                            $field852->subfield('z') || $NULL_STRING;
   my %captions = ();
   my %holdingdata = ();

   foreach my $field ($record->field('853')) {
      $captions{$field->subfield('8')} = $field->subfield('a') || $NULL_STRING;
   }

   foreach my $field ($record->field('863')) {
      my ($which,$sub) = split (/\./,$field->subfield('8'));
      my $temp_holdings = $NULL_STRING;
      my $sub_a = $field->subfield('a') || $NULL_STRING;
      my $sub_i = $field->subfield('i') || $NULL_STRING;
      my $sub_z = $field->subfield('z') || $NULL_STRING;
      if ($sub_a . $sub_i ne $NULL_STRING) {
         if ($sub_a ne $NULL_STRING) {
            $temp_holdings .= $captions{$which} .' '. $sub_a .' ';
         }
         if ($sub_i ne $NULL_STRING) {
            $temp_holdings .= '(' . $sub_i . ')';
         }
      }
      if ($sub_z ne $NULL_STRING) {
         $temp_holdings .= '; ' . $sub_z ;
      }
      $temp_holdings =~ s/^; //;
      $holdingdata{$which}{$sub} = $temp_holdings;
   }

   foreach my $which (sort keys %holdingdata) {
      foreach my $sub (sort keys %{$holdingdata{$which}}) {
         $holdings .= $holdingdata{$which}{$sub} . "\n";
      }
   }

   %holdingdata = ();
   my $subholdingsdata = $NULL_STRING;
TAG866:
   foreach my $field ($record->field('866')) {
      if (!$field->subfield('8')) {
         $subholdingsdata .= $field->subfield('a')."\n";
         next TAG866;
      }
      my ($which,$sub) = split (/\./,$field->subfield('8'));
      $holdingdata{$which}{$sub} = $field->subfield('a');
   }
   foreach my $which (sort keys %holdingdata) {
      foreach my $sub (sort keys %{$holdingdata{$which}}) {
         if ($holdingdata{$which}{$sub}){
            $holdings .= $holdingdata{$which}{$sub} . "\n";
         }
      }
   }
   $holdings .= $subholdingsdata;

   my $keep_holdings = $holdings;

#   %holdingdata = ();
#   $subholdingsdata = $NULL_STRING;
#TAG867:
#   foreach my $field ($record->field('867')) {
#      if (!$field->subfield('8')) {
#         $subholdingsdata .= $field->subfield('a')."\n";
#         next TAG867;
#      }
#      my ($which,$sub) = split (/\./,$field->subfield('8'));
#      $holdingdata{$which}{$sub} = $field->subfield('a');
#   }
#   if (scalar(keys(%holdingdata)) > 0) {
#      $holdings .= "Supplements:\n";
#   }
#   foreach my $which (sort keys %holdingdata) {
#      foreach my $sub (sort keys %{$holdingdata{$which}}) {
#         $holdings .= $holdingdata{$which}{$sub} . "\n";
#      }
#   }
#   $holdings .= $subholdingsdata;
#
#   %holdingdata = ();
#   $subholdingsdata = $NULL_STRING;
#TAG868:
#   foreach my $field ($record->field('868')) {
#      if (!$field->subfield('8')) {
#         $subholdingsdata .= $field->subfield('a')."\n";
#         next TAG868;
#      }
#      my ($which,$sub) = split (/\./,$field->subfield('8'));
#      $holdingdata{$which}{$sub} = $field->subfield('a');
#   }
#   if (scalar(keys(%holdingdata)) > 0) {
#      $holdings .= "Indexes:\n";
#   }
#   foreach my $which (sort keys %holdingdata) {
#      foreach my $sub (sort keys %{$holdingdata{$which}}) {
#         $holdings .= $holdingdata{$which}{$sub} . "\n";
#      }
#   }
#   $holdings .= $subholdingsdata;

   chomp $holdings;
   chomp $keep_holdings;
   my $new_field=MARC::Field->new('866',' ',' ','a' => $keep_holdings, 'b' => $location);
   $biblio->insert_fields_ordered($new_field);

   $debug and say "HOLDINGS: $holdings";
   $debug and print $biblio->as_formatted();

   if ($doo_eet) {
      ModBiblio($biblio,$biblio_map{$bib_id});
   }

   $written++;
}

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

say "Locations used:";
foreach my $kee (sort keys %locations_used) {
    say "$kee:  $locations_used{$kee}";
}

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
