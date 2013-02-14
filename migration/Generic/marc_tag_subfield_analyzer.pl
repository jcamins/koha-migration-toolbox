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
#   -input MARC file
#   -which tag to analyze
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -number of records read
#   -number of tags found
#   -subfields used, and counts

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use IO::File;
use MARC::Batch;
use MARC::Charset;
use MARC::Record;
use MARC::Field;

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
my $tag_to_check   = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'tag=s'    => \$tag_to_check,
    'debug'    => \$debug,
);

for my $var ($input_filename, $tag_to_check) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();
my %tagcount = ();
my $tags_found = 0;

RECORD:
while () {
   my $record;
   eval {$record = $batch->next();};
   if ($@) {
      print "Bogus record skipped.\n";
      $problem++;
      next RECORD;
   }
   last RECORD unless ($record);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

TAG:
   foreach my $tag ($record->field($tag_to_check)) {
   $tags_found++;
SUBFIELD:
      foreach my $sub ($tag->subfields()){
         my ($code,$val) = @$sub;
         $tagcount{$code}++;
      }
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$tags_found $tag_to_check tags located and analyzed.
END_REPORT

say 'Subfield count:';
foreach my $kee (sort keys %tagcount) {
   say "$kee:  $tagcount{$kee}";
}

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
