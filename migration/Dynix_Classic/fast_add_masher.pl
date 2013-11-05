#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -nothing
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -nothing

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
use Date::Calc qw(Add_Delta_Days);

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
my $codes_filename    = $NULL_STRING;
my @datamap_filenames;
my %datamap;


GetOptions(
    'in=s'     => \$input_filename,
    'bib=s'    => \$bib_data_filename,
    'out=s'    => \$output_filename,
    'codes=s'  => \$codes_filename,
    'map=s'    => \@datamap_filenames,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename,$bib_data_filename,$output_filename,$codes_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

Readonly my $FIELD_SEP    => chr(254);
Readonly my $TAG_SEP      => chr(253);
my @subfields_possible = qw/a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9/;

foreach my $map (@datamap_filenames) {
   my ($mapsub,$map_filename) = split (/:/,$map);
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$map_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $datamap{$mapsub}{$data[0]} = $data[1];
   }
   close $mapfile;
}

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

my %homebranchcounts;
my %holdbranchcounts;
my %itypecounts;
my %locationcounts;
my %ccodecounts;
my %callschemecounts;
$i = 0;

open my $input_file,'<:utf8',$input_filename;
open my $output_file,'>:utf8',$output_filename;
LINE:
while (my $line=readline($input_file)) {
   last LINE if $debug && $i>0;
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

   my $keep_itype;
   my $keep_issues = 0;
   my $title_line = $subrecord_hash{$columns[1]};
   $title_line =~ s///g;
   my @title_columns = split /$FIELD_SEP/, $title_line;

   my $title = MARC::Field->new('245',' ',' ', 'a' => $title_columns[7]);
   my $record=MARC::Record->new();
   $record->leader('     nam a22        4500');
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

   my %item;

   $item{barcode} = $NULL_STRING;
   $item{itype}   = 'UNKNOWN';
   $item{branch}  = 'UNKNOWN';

   $item{barcode} = $columns[0];

   my @subcolumns = split /$TAG_SEP/,$columns[2];
   if ($subcolumns[0]){
      my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$subcolumns[0]);
      $item{date_acquired}   = sprintf "%4d-%02d-%02d",$year,$month,$day;
   }

   $item{itype} = $columns[3];

   @subcolumns = split /$TAG_SEP/,$columns[4];
   if (defined $subcolumns[0]) {
      $item{checkouts} = $subcolumns[0];
   }

   $item{itemcallnumber} = $columns[5];
   $item{branch}         = $columns[7];
   $item{location}       = $columns[8];

   if (defined $columns[10]) {
      @subcolumns = split /$TAG_SEP/,$columns[10];
      if (defined $subcolumns[0]) {
         my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$subcolumns[0]);
         $item{last_borrowed}   = sprintf "%4d-%02d-%02d",$year,$month,$day;
      }
   }

   if (defined $columns[15]) {
      $item{collcode} = $columns[15];
      $item{collcode} =~ s/\r//g;
   }

   if (defined $columns[16]) {
      $item{enumchron} = $columns[16];
   }

   $item{price} = 0;
   if (defined $columns[17]) {
      $item{price} = $columns[17];
      $item{price} =~ s/\r//g;
      if ($item{price} ne $NULL_STRING){
         $item{price} /= 100;
      }
   }

   if (defined $columns[20]){
      @subcolumns = split /$TAG_SEP/, $columns[20];
      foreach my $subcolumn (@subcolumns){
         $item{nonpublic_note} .= ' | '.$subcolumn;
      }
   }

   if (defined $columns[21]) {
      @subcolumns = split /$TAG_SEP/, $columns[21];
      foreach my $subcolumn (@subcolumns){
         $item{nonpublic_note} .= ' | '.$subcolumn;
      }
   }

   if (exists $item{nonpublic_note}) {
      $item{nonpublic_note} =~ s/^ \| //;
   }

   if ($item{barcode} eq $NULL_STRING
       || $item{branch} eq $NULL_STRING
       || $item{itype}  eq $NULL_STRING) {
      $problem++;
      next LINE;
   }
   
   my $field=MARC::Field->new('952',' ',' ',
                              'a' => $item{branch},
                              'b' => $item{branch},
                              'p' => $item{barcode},
                              'y' => $item{itype});

   $field->update( 'c' => $item{location} )       if ($item{location});
   $field->update( 'd' => $item{date_acquired} )  if ($item{date_acquired});
   $field->update( 'g' => $item{price} )          if ($item{price});
   $field->update( 'l' => $item{checkouts} )      if ($item{checkouts});
   $field->update( 'o' => $item{itemcallnumber} ) if ($item{itemcallnumber});
   $field->update( 's' => $item{last_borrowed} )  if ($item{last_borrowed});
   $field->update( 'h' => $item{enumchron} )      if ($item{enumchron});
   $field->update( 'x' => $item{nonpublic_note} ) if ($item{nonpublic_note});
   $field->update( 'z' => $item{note} )           if ($item{note});
   $field->update( '8' => $item{collcode} )       if ($item{collcode});


   for my $subfield (@subfields_possible) {
      if (defined $field->subfield($subfield)) {
         my $oldval = $field->subfield($subfield);
         if ($datamap{$subfield}{$oldval}) {
            $field->update( $subfield => $datamap{$subfield}{$oldval} );
            if ($datamap{$subfield}{$oldval} eq 'NULL') {
               $field->delete_subfield( code => $subfield ,match => qr/^NULL$/ );
            }
         }
      }
   }

   $homebranchcounts{$field->subfield('a')}++;
   $holdbranchcounts{$field->subfield('b')}++;
   $itypecounts{$field->subfield('y')}++;
   $keep_itype = $field->subfield('y');
   if ($field->subfield('l')) {
      $keep_issues += $field->subfield('l');
   }
   if ($field->subfield('c')) {
      $locationcounts{$field->subfield('c')}++;
   }
   if ($field->subfield('8')) {
      $ccodecounts{$field->subfield('8')}++;
   }
   if ($field->subfield('2')) {
      $callschemecounts{$field->subfield('2')}++;
   }

   $record->insert_fields_ordered($field);

   my $field2 = MARC::Field->new('942',' ',' ','c' => $keep_itype,
                                               '0' => $keep_issues,
                                );
   $record->insert_fields_ordered($field2);

   print {$output_file} $record->as_usmarc();
   $written++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

open my $codes_file,'>',$codes_filename;

print "\nHOMEBRANCHES:\n";
foreach my $kee (sort keys %homebranchcounts){
   print $kee.":   ".$homebranchcounts{$kee}."\n";
   print {$codes_file} "REPLACE INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print "\nHOLDBRANCHES:\n";
foreach my $kee (sort keys %holdbranchcounts){
   print $kee.":   ".$holdbranchcounts{$kee}."\n";
   if (!$homebranchcounts{$kee}) {
      print {$codes_file} "REPLACE INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
   }
}
print "\nITEM TYPES:\n";
foreach my $kee (sort keys %itypecounts){
   print $kee.":   ".$itypecounts{$kee}."\n";
   print {$codes_file} "REPLACE INTO itemtypes (itemtype,description) VALUES ('$kee','$kee');\n";
}
print "\nSHELVING LOCATIONS:\n";
foreach my $kee (sort keys %locationcounts){
   print $kee.":   ".$locationcounts{$kee}."\n";
   print {$codes_file} "REPLACE INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','$kee');\n";
}
print "\nCOLLECTION CODES:\n";
foreach my $kee (sort keys %ccodecounts){
   print $kee.":   ".$ccodecounts{$kee}."\n";
   print {$codes_file} "REPLACE INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','$kee');\n";
}
print "\nCALL SCHEMA:\n";
foreach my $kee (sort keys %callschemecounts){
   print $kee.":   ".$callschemecounts{$kee}."\n";
}
print "\n";

exit;
