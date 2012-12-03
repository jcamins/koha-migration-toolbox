#!/usr/bin/perl
#-------------------------------------------
# Copyright 2012 C & P Bibliography Services
#
#-------------------------------------------
#
# -Jared Camins-Esakov
# 
# Modification log: JCE 2012/12/03
#
#-------------------------------------------
#
# EXPECTS:
#   -an input file, an output file, a starting id, and a field/subfield to populate with ids
#
# DOES:
#   -populates a specified field with an id
#
# REPORTS:
#   -how many records it processed

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use IO::File;
use MARC::Batch;
use MARC::Record;
use MARC::Field;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;
my $xml = 0;
my $start = 0;

my $input_filename = $NULL_STRING;
my $output_filename = $NULL_STRING;
my $field = '001';
my $subfield = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'out=s'    => \$output_filename,
    'xml'      => \$xml,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
    'start=i'    => \$start,
    'field'    => \$field,
    'subfield' => \$subfield,
);

die "Invalid tag specification" unless ( $field && ($field < 10 || $subfield =~ /[a-z0-9]/) );
my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);

open my $output_file,'>:utf8',$output_filename;

my $nextid = $start;
my $record;

RECORD:
while() {
    last RECORD if ($debug && $i>1000);
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
    print "Assigning record $i ID $nextid\n" if $debug;
    if ( $field < 10 ) {
        $record->insert_grouped_field( MARC::Field->new( $field, $nextid++ ) );
    } else {
        $record->insert_grouped_field( MARC::Field->new( $field, ' ', ' ', $subfield => $nextid++ ) );
    }
    print $output_file $record->as_usmarc();
    $written++;
}
close $input_file;
close $output_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;

