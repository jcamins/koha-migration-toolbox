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
my $output_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'problem=s' => \$output_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename, $output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $problem2   = 0;
my $stop_point = 0;
my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();

open my $output_file,'>',$output_filename;

my $dbh = C4::Context->dbh();
my $find_subscription_sth = $dbh->prepare("SELECT * FROM subscription WHERE internalnotes = ?");
my $update_subscription_sth = $dbh->prepare("UPDATE subscription SET callnumber = ?, internalnotes = ?, notes = ? 
                                             WHERE subscriptionid = ?");
my $update_subscription_hist_sth = $dbh->prepare("UPDATE subscriptionhistory SET recievedlist=? WHERE subscriptionid = ?");

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

   my $subscription_id = $NULL_STRING;

FIELD001:
   foreach my $field ($record->field('001')) {
      my $data = $field->data();
      if ($data =~ m/\.c/) {
         $subscription_id = '('. substr($data,1) . ')';
         last FIELD001;
      }
   }
   if ($subscription_id eq $NULL_STRING) {
      say "Problem:  Subscription ID not found in MHLD record #$i.";
      $problem++;
      next RECORD;
   }

   $find_subscription_sth->execute($subscription_id);
   my $subscription = $find_subscription_sth->fetchrow_hashref();
   if (!$subscription) {
      say "Problem: Subscription not found $subscription_id.";
      $problem2++;
      print {$output_file} $record->as_usmarc();
      next RECORD;
   }
#   $debug and print Dumper($subscription);
   my $biblio = GetMarcBiblio($subscription->{biblionumber});
   if (!$biblio) {
      say "Problem: Biblio not found $subscription->{biblionumber}.";
      $problem++;
   }
   $biblio->insert_fields_ordered($record->field('8..'));
   $debug and say "MHLD:";
   $debug and print $record->as_formatted();

   my $callnum = $NULL_STRING;
   my $note    = $NULL_STRING;
   my $holdings = $NULL_STRING;

   foreach my $field ($record->field('852')) {
      my $sub_h = $field->subfield('h') || undef;
      my $sub_z = $field->subfield('z') || undef;
      if ($sub_h) {
         $callnum .= $sub_h."\n";
      }
      if ($sub_z) {
         $note .= $sub_z."\n";
      }
   }
   chomp ($callnum);
   chomp ($note);

   my $caption = $record->subfield('853','a') || $NULL_STRING;
   foreach my $field ($record->field('863')) {
      my $sub_a = $field->subfield('a') || $NULL_STRING;
      my $sub_i = $field->subfield('i') || $NULL_STRING;
      my $sub_z = $field->subfield('z') || $NULL_STRING;
      if ($sub_a . $sub_i ne $NULL_STRING) {
         if ($sub_a ne $NULL_STRING) {
            $holdings .= $caption .' '. $sub_a .' ';
         }
         if ($sub_i ne $NULL_STRING) {
            $holdings .= '(' . $sub_i . ')';
         }
      }
      if ($sub_z ne $NULL_STRING) {
         $holdings .= '; ' . $sub_z ;
      }
      $holdings .= "\n";
      $holdings =~ s/^; //;
   }
   my $formatted_holdings = $holdings;

   if ($record->field('866')) {
      $holdings .= "Holdings: ";
      foreach my $field ($record->field('866')) {
         $holdings .= $field->subfield('a') . '; ';
      }
      $holdings =~ s/; $//;
      $holdings .= "\n";
   } 

   if ($record->field('867')) {
      $holdings .= "Supplements: ";
      foreach my $field ($record->field('867')) {
         $holdings .= $field->subfield('a') . '; ';
      }
      $holdings =~ s/; $//;
      $holdings .= "\n";
   } 

   if ($record->field('868')) {
      $holdings .= "Indexes: ";
      foreach my $field ($record->field('868')) {
         $holdings .= $field->subfield('a') . '; ';
      }
      $holdings =~ s/; $//;
      $holdings .= "\n";
   } 
   chomp $holdings;

   chomp $formatted_holdings;
   if ($formatted_holdings ne $NULL_STRING) {
      my $field=MARC::Field->new('866',' ',' ','a' => $formatted_holdings);
      $biblio->insert_fields_ordered($field);
      $stop_point = 1;
   }

   $debug and print "\n";
   $debug and say "Callnum: $callnum";
   $debug and say "Notes: $note";
   $debug and say "Holdings: $holdings";
   $debug and say "BIBLIO:";
   $debug and print $biblio->as_formatted();

   if ($doo_eet) {
      ModBiblio($biblio,$subscription->{biblionumber});
      $update_subscription_sth->execute($callnum,$note,$holdings,$subscription->{subscriptionid});
      $update_subscription_hist_sth->execute($holdings,$subscription->{subscriptionid});
   }

   $written++;
}

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
$problem2 records sent for no-subscription processing.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
