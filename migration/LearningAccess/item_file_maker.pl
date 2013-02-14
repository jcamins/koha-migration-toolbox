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
#
# DOES:
#   -nothing
#
# CREATES:
#   -item CSV for use by the biblio masher
#
# REPORTS:
#   -number of records read
#   -number of items written

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

my $input_filename    = $NULL_STRING;
my $output_filename   = $NULL_STRING;
my $holdings_filename = $NULL_STRING;
my $url_filename      = $NULL_STRING;
my $barmap_filename   = $NULL_STRING;

GetOptions(
    'in=s'      => \$input_filename,
    'out=s'     => \$output_filename,
    'hold=s'    => \$holdings_filename,
    'url=s'     => \$url_filename,
    'bar_map=s' => \$barmap_filename,
    'debug'     => \$debug,
);

for my $var ($input_filename,$output_filename,$holdings_filename,$url_filename,$barmap_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}


my @item_fields = qw( itype system branch location location2
                      itemcallnum itemcallnum2 seen  checkouts status 
                      public_note nonpub_note copynum copynum2 enumchron 
                      price price2 aqdate replprice aqsrc parts
                    );

my $input_file = IO::File->new($input_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();

open my $output_file,'>:utf8',$output_filename;
print {$output_file} 'bibnum|barcode|def_branch|';
foreach my $field (@item_fields) {
   print {$output_file} "$field|";
}
print {$output_file} "\n";

open my $holdings_file,'>:utf8',$holdings_filename;
open my $url_file,'>:utf8',$url_filename;
open my $barmap_file,'>:utf8',$barmap_filename;
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
   my $this_bib = $NULL_STRING;
   my $default_branch = $NULL_STRING;
   my $enum_1 = $NULL_STRING;
   my $enum_2 = $NULL_STRING;
   my $enum_3 = $NULL_STRING;
   my $enum_4 = $NULL_STRING;
   my $enum_5 = $NULL_STRING;
   my $enum_6 = $NULL_STRING;
   my %items;
   my %primary_barcodes;

TAG:
   foreach my $tag ($record->fields()) {
      if ($tag->tag() eq '004') {
         $this_bib = $tag->data();
      }
      next TAG if ($tag->tag() < 800 );
      next TAG if ($tag->tag() eq '854');
      next TAG if ($tag->tag() eq '956');

      if ($tag->tag() eq '856') {
         print {$url_file} "$this_bib,";
         print {$url_file} $tag->indicator(1).',';
         print {$url_file} $tag->indicator(2).',"';
         foreach my $sub ($tag->subfields()) {
            my ($code,$data_out) = @$sub;
            $data_out =~ s/\"/'/g;
            print {$url_file} "~$code!$data_out";
         }
         print {$url_file} "\n";
         next TAG;
      }

      if ($tag->tag() eq '866') {
         print {$holdings_file} "$this_bib,";
         my $data_out = $tag->as_string();
         $data_out =~ s/\"/'/g;
         print {$holdings_file} '"'.$data_out.'"'."\n";
         next TAG;
      }

      if ($tag->tag() eq '852') {
         $default_branch = $tag->subfield('b') || $NULL_STRING;
         next TAG;
      }

      if ($tag->tag() eq '853') {
         $enum_1 = $tag->subfield('a') || $NULL_STRING;
         $enum_2 = $tag->subfield('b') || $NULL_STRING;
         $enum_3 = $tag->subfield('c') || $NULL_STRING;
         $enum_4 = $tag->subfield('d') || $NULL_STRING;
         $enum_5 = $tag->subfield('e') || $NULL_STRING;
         $enum_6 = $tag->subfield('f') || $NULL_STRING;
         next TAG;
      }

      if ($tag->tag() eq '863') {
         my $barcode = $tag->subfield('p');
         next TAG if (!$barcode);
         my $enumchron = $NULL_STRING;
         $enumchron .= $enum_1.' '.$tag->subfield('a') if ($tag->subfield('a')); 
         $enumchron .= ',' .$enum_2.' '.$tag->subfield('b') if ($tag->subfield('b')); 
         $enumchron .= ',' .$enum_3.' '.$tag->subfield('c') if ($tag->subfield('c')); 
         $enumchron .= ',' .$enum_4.' '.$tag->subfield('d') if ($tag->subfield('d')); 
         $enumchron .= ',' .$enum_5.' '.$tag->subfield('e') if ($tag->subfield('e')); 
         $enumchron .= ',' .$enum_6.' '.$tag->subfield('f') if ($tag->subfield('f')); 
         $items{$barcode}{enumchron} = $enumchron;
         next TAG;
      }

      if ($tag->tag() eq '876') {
         my $barcode = $tag->subfield('p');
         next TAG if (!$barcode);
         my $sub_8 = $tag->subfield('8') || '1.1';
         if (!exists $primary_barcodes{$sub_8}) {
            $primary_barcodes{$sub_8} = $barcode;
            $items{$barcode}{parts} = $NULL_STRING;
         }
         else {
            $items{$primary_barcodes{$sub_8}}{parts} .= $barcode . ' ';
         }
         print {$barmap_file} $tag->subfield('a').','.$barcode."\n" if ($tag->subfield('a'));
         $items{$barcode}{price}    = $tag->subfield('c') || $NULL_STRING;
         $items{$barcode}{location} = $tag->subfield('l') || $NULL_STRING;
         $items{$barcode}{copynum}  = $tag->subfield('t') || $NULL_STRING;
         next TAG;
      }

     if ($tag->tag() eq '952') {
         my $barcode = $tag->subfield('p');
         next TAG if (!$barcode);
         $items{$barcode}{system}     = $tag->subfield('a') || $NULL_STRING;
         $items{$barcode}{branch}     = $tag->subfield('b') || $NULL_STRING;
         $items{$barcode}{location2}  = $tag->subfield('c') || $NULL_STRING;
         $items{$barcode}{seen}       = $tag->subfield('d') || $NULL_STRING;
         $items{$barcode}{checkouts}  = $tag->subfield('e') || $NULL_STRING;
         $items{$barcode}{status}     = $tag->subfield('f') || $NULL_STRING;
         $items{$barcode}{copynum2}    = $tag->subfield('t') || $NULL_STRING;
         my $itemcallnum = $NULL_STRING;
         $itemcallnum .= $tag->subfield('k').' ' if ($tag->subfield('k'));
         $itemcallnum .= $tag->subfield('h')     if ($tag->subfield('h'));
         $itemcallnum .= ' '.$tag->subfield('i') if ($tag->subfield('i'));
         $itemcallnum .= ' '.$tag->subfield('m') if ($tag->subfield('m'));
         $items{$barcode}{itemcallnum} = $itemcallnum;
         next TAG;
      }

      if ($tag->tag() eq '976') {
         my $barcode = $tag->subfield('p');
         next TAG if (!$barcode);
         $items{$barcode}{itype}       = $tag->subfield('a') || $NULL_STRING;
         $items{$barcode}{public_note} = $tag->subfield('x') || $NULL_STRING;
         $items{$barcode}{nonpub_note} = $tag->subfield('z') || $NULL_STRING;
         my $itemcallnum = $NULL_STRING;
         $itemcallnum .= $tag->subfield('k').' ' if ($tag->subfield('k'));
         $itemcallnum .= $tag->subfield('h')     if ($tag->subfield('h'));
         $itemcallnum .= ' '.$tag->subfield('i') if ($tag->subfield('i'));
         $items{$barcode}{itemcallnum2} = $itemcallnum;
         next TAG;
      }

      if ($tag->tag() eq '990') {
         my $barcode = $tag->subfield('p');
         next TAG if (!$barcode);
         $items{$barcode}{price2}    = $tag->subfield('c') || $NULL_STRING;
         $items{$barcode}{aqdate}    = $tag->subfield('d') || $NULL_STRING;
         $items{$barcode}{replprice} = $tag->subfield('r') || $NULL_STRING;
         $items{$barcode}{aqsrc}     = $tag->subfield('v') || $NULL_STRING;
         next TAG;
      }
   }

   foreach my $kee (sort keys %items) {
      if (exists ($items{$kee}{parts}) && $items{$kee}{parts} ne $NULL_STRING) {
         foreach my $bar (split / /, $items{$kee}{parts}) {
            $items{$bar}{DUMP} = 1;
         }
      }
   }
   
   foreach my $kee (sort keys %items) {
      next if $items{$kee}{DUMP};
      print {$output_file} "$this_bib|$kee|$default_branch|";
      foreach my $field (@item_fields) {
         my $data_out=$items{$kee}{$field} || $NULL_STRING;
         $data_out =~ s/\"//g;
         $data_out =~ s/\t//g;
         $data_out =~ s///g;
         $data_out =~ s/\n//g;
         print {$output_file} $data_out;
         print {$output_file} '|';
      }
      print {$output_file} "\n";
      $written++;
   }
}
close $input_file;
close $output_file;
close $holdings_file;
close $url_file;
close $barmap_file;

print << "END_REPORT";

$i records read.
$written item records written.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
