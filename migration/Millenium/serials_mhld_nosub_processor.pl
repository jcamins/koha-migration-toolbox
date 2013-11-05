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

GetOptions(
    'in=s'     => \$input_filename,
    'biblio_map=s' => \$biblio_map_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename, $biblio_map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
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

my $stop_point = 0;
my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();

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
      $debug and say "DATA: $data";
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
   $biblio->insert_fields_ordered($record->field('8..'));
   $debug and say "MHLD:";
   $debug and print $record->as_formatted();
   $debug and say "BIBLIO:";
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

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
