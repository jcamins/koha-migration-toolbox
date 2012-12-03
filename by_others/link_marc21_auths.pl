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
#   -input file name, link file, output file name
#
# DOES:
#   -links 5xx fields in the input file to records in the link file
#
# REPORTS:
#   -number of headings linked and records processed

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
my $idfield = '001';
my @fields;

my $input_filename = $NULL_STRING;
my $output_filename = $NULL_STRING;
my $link_filename = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'out=s'    => \$output_filename,
    'link=s'   => \$link_filename,
    'debug'    => \$debug,
    'id=s'  => \$idfield,
    'field=s'  => \@fields,
);

#die "Must supply fields and link file" unless ( $fields && $link_filename );

my %links;
my $link_file  = IO::File->new($link_filename);
my $link_batch = MARC::Batch->new('USMARC',$link_file);

LINK:
while () {
    last LINK if ($debug && $i>1000);
    my $record;
    eval {$record = $link_batch->next();};
    if ($@) {
        print "Bogus link skipped.\n";
        next LINK;
    }
    last LINK unless ($record);

    $links{$record->field('1..')->as_string('abcdfghijklmnopqrstuvxyz')} = $record->field('001')->data();
}
close $link_file;

my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);

open my $output_file,'>:utf8',$output_filename;

my $record;
my $updated = 0;

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
    my @fields = $record->field('5..');
    foreach my $field (@fields) {
        if ($links{$field->as_string('abcdfghijklmnopqrstuvxyz')}) {
            $field->update( '9' => $links{$field->as_string('abcdfghijklmnopqrstuvxyz')} );
            $updated++;
        }
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
$updated headings updated.
END_REPORT

exit;


