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
#   -MARC authority file
#   -designation of match point
#
# DOES:
#   -matches-and-loads MARC authorites, if --update is specified
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -counts of records read, overlaid, and added

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
use C4::AuthoritiesMarc;
use MARC::Record;
use MARC::Field;
use MARC::Charset;
use MARC::Batch;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = $NULL_STRING;
my $matchtag       = $NULL_STRING;
my $matchsub       = $NULL_STRING;
my $charset        = 'marc8';


GetOptions(
    'in=s'      => \$input_filename,
    'tag=s'     => \$matchtag,
    'sub=s'     => \$matchsub,
    'charset=s' => \$charset,
    'debug'     => \$debug,
    'update'    => \$doo_eet,
);

for my $var ($input_filename,$matchtag) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if ($matchtag > 9 && $matchsub eq $NULL_STRING) {
   print "--sub needed when --tag > 009.\n";
   exit;
}

my %map;
my $mapped            = 0;
my $field_not_present = 0;

my $dbh=C4::Context->dbh();
my $dum=MARC::Charset->ignore_errors(1);
my $sth=$dbh->prepare("SELECT authid FROM auth_header");
my $marc_sth=$dbh->prepare("SELECT marc FROM auth_header WHERE authid=?");
$sth->execute();

MAP_RECORD:
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $marc_sth->execute($row->{authid});
   my $rec = $marc_sth->fetchrow_hashref();
   my $marc;
   eval {$marc = MARC::Record->new_from_usmarc($rec->{marc}); };
   if ($@){
      print "bogus record skipped\n";
      next MAP_RECORD;
   }
   my $field;
   if ($matchtag < 10){
      my $tagg = $marc->field($matchtag);
      if ($tagg){
         $field = $tagg->data();
      }
   }
   else{
      $field = $marc->subfield($matchtag,$matchsub);
   }
   if (!$field){
      $field_not_present++;
      next MAP_RECORD;
   }
   $field =~ s/\"/'/g;
   if ($field =~ m/\,/){
      $field = '"'.$field.'"';
   }
   $map{$field} = $row->{authid};
   $mapped++;
}

print "\n$i records read from database.\n$mapped records in the match map.\n";
print "$field_not_present records not considered due to missing or invalid field.\n\n";

$i=0;
my $modified = 0;

my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
my $setting    = MARC::Charset::assume_encoding($charset);
$batch->warnings_off();
$batch->strict_off();

print "Processing authority records:\n";

RECORD:
while() {
   last RECORD if ($debug && $i>10);
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

   my $field;
   if ($matchtag < 10){
      my $tagg = $record->field($matchtag);
      if ($tagg){
         $field = $tagg->data() || $NULL_STRING;
      }
   }
   else{
      $field = $record->subfield($matchtag,$matchsub) || $NULL_STRING;
   }
   $field =~ s/\"/'/g;
   if ($field =~ m/\,/){
      $field = '"'.$field.'"';
   }
   my $authtypecode=GuessAuthTypeCode($record);

   if ($field ne $NULL_STRING && (exists $map{$field})) {
      $debug and print "\t\t\tModifying authority # $map{$field}\n";
      $doo_eet and ModAuthority($map{$field},$record,$authtypecode);
      $modified++;
   }
   else {
      $debug and print "Adding authority $field\n";
      $doo_eet and AddAuthority($record,undef,$authtypecode);
      $written++;
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$modified records overlaid.
$problem records not loaded due to problems.
END_REPORT

exit;      
