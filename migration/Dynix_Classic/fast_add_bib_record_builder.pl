#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

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

my $input_filename    = $NULL_STRING;
my $bib_data_filename = $NULL_STRING;
my $output_filename   = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'bib=s'    => \$bib_data_filename,
    'out=s'    => \$output_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$bib_data_filename,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

Readonly my $FIELD_SEP    => chr(254);
Readonly my $TAG_SEP      => chr(253);
my @subfields_possible = qw/a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9/;

my %subrecord_hash;
print "Loading subrecord data into memory.\n";
open my $subrecord_file,'<',$bib_data_filename;
while (my $line = readline($subrecord_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s/^M$//;
   my ($record_number,$rest) = split /$FIELD_SEP/,$line;
   $subrecord_hash{$record_number} = $line;
}
close $subrecord_file;
print "\n\n";

my %column_to_field=( 10 => '010',
                     11 => '020',
                     12 => '022',
                     24 => '250',
                     29 => '300',
                     32 => '440',
                     34 => '500',
                     36 => '504',
                     37 => '505',
                     38 => '508',
                     39 => '511',
                     40 => '540',
                     43 => '650',
                     44 => '690',
                     46 => '690',
                     47 => '740',
                   );

$i = 0;
open my $input_file,'<:utf8',$input_filename;
open my $output_file,'>:utf8',$output_filename;
LINE:
while (my $line=readline($input_file)) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   chomp $line;
   $line =~ s///g; 
   $debug and print $line."\n";
   my @columns = split /$FIELD_SEP/,$line;
   $debug and print Dumper(@columns);
   if (!exists $subrecord_hash{$columns[1]}) {
      $problem++;
      next LINE;
   }

   my $title_line = $subrecord_hash{$columns[1]};
   $title_line =~ s///g;
   $title_line =~ s/\"/'/g;
   my @title_columns = split /$FIELD_SEP/, $title_line;
   my $record=MARC::Record->new();
   $record->leader('     nam a22        4500');
   my $bibnum = MARC::Field->new('998',' ',' ','a' => $columns[1]);
   $record->insert_fields_ordered($bibnum);

   my $title = MARC::Field->new('245',' ',' ', 'a' => $title_columns[7]);
   if (defined $title_columns[20] && $title_columns[20] ne $NULL_STRING) {
      $title->update( 'c' => $title_columns[20]);
   }
   if (defined $title_columns[21] && $title_columns[21] ne $NULL_STRING) {
      $title->update( 'h' => $title_columns[21]);
   }
   $record->insert_fields_ordered($title);

   if (defined $title_columns[8] && $title_columns[8] ne $NULL_STRING) {
      my @authors = split /$TAG_SEP/,$title_columns[8];
      my $auth = MARC::Field->new('100',' ',' ', 'a' => $authors[0]);
      $record->insert_fields_ordered($auth);
      for my $k (1..scalar(@authors)) {
         if (defined $authors[$k] && $authors[$k] ne $NULL_STRING) {
            my $subauth = MARC::Field->new('700',' ',' ', 'a' => $authors[$k]);
            $record->insert_fields_ordered($subauth);
         }
      } 
   }

   my $f260 = MARC::Field->new('260',' ',' ','9' => 'DUM');
   if (defined $title_columns[25] && $title_columns[25] ne $NULL_STRING) {
      $f260->update( 'a' => $title_columns[25]);
   }
   if (defined $title_columns[26] && $title_columns[26] ne $NULL_STRING) {
      $f260->update( 'b' => $title_columns[26]);
   }
   if (defined $title_columns[27] && $title_columns[27] ne $NULL_STRING) {
      $f260->update( 'c' => $title_columns[27]);
   }
   $f260->delete_subfield(code => '9');
   $record->insert_fields_ordered($f260);

   foreach my $kee (sort keys %column_to_field) {
      if (defined $title_columns[$kee] && $title_columns[$kee] ne $NULL_STRING) {
         my @tags = split /$TAG_SEP/,$title_columns[$kee];
         foreach my $tag (@tags) {
            my $field = MARC::Field->new($column_to_field{$kee},' ',' ','a' => $tag);
            $record->insert_fields_ordered($field);
         }
      }
   } 

   print {$output_file} $columns[0].',"'.$record->as_usmarc().'"'."\n";;
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;
