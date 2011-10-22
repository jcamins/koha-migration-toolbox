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
#   -file of authorized terms, one per line
#   -designation of type of authority record to be created.  See hash %record_types for valid values.
#
# DOES:
#   -nothing
#
# CREATES:
#   -MARC file of authority records
#
# REPORTS:
#   -count of records read
#   -count of MARCs built and output

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

use MARC::Record;
use MARC::Field;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename  = $NULL_STRING;
my $record_type     = $NULL_STRING;
my $output_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'type=s'   => \$record_type,
    'out=s'    => \$output_filename,
    'debug'    => \$debug,
);

for my $var ($input_filename,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my %record_types=(
                     'person'   => '100',
                     'title'    => '130',
                     'subject'  => '150',
                 );

open my $input_file, '<',$input_filename;
open my $output_file,'>',$output_filename;

LINE:
while (my $line=readline($input_file)){
   last RECORD if ($debug and $written>20);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s///g;
   $line =~ s/^\s+//g;
   $line =~ s/\s+$//g;

   next LINE if length($line) eq 0;


   my $new_record = MARC::Record->new();
   $new_record->leader('     nz a22     o  4500');

   my $new_field = MARC::Field->new( $record_types{$record_type} ,' ',' ', 'a' => $line );
   $new_record->insert_grouped_field($new_field);

   my $new_008 = MARC::Field->new( '008','      |a ||z||||||          || ||    |u');
   $new_record->insert_grouped_field($new_008);

   my $new_667 = MARC::Field->new( '667',' ',' ','a' => 'Created during migration to Koha.' );
   $new_record->insert_grouped_field($new_667);
   
   $debug and print $new_record->as_formatted();
   $debug and print "\n";
 
   print {$output_file} $new_record->as_usmarc();
   $written++;
}
close $output_file;
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

exit;
