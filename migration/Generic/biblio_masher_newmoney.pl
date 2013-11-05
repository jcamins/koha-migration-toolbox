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
#   -file of MARC records
#   -file of CSV-delimited item records (optional)
#
# DOES:
#   -nothing
#
# CREATES:
#   -Koha MARC file
#
# REPORTS:
#   -count of records added
#
# Notes:
#   This script uses command-line directives to do stuff to the MARC records.  Possible directives:
#
#   --drop_noitems   Will cause the MARC record to be tossed if no items are present.
#
#   --dropfields=    Fields to toss out of the MARC record JUST BEFORE adding 942 and 952 entries.  This can be in the form used
#                    by MARC::Record->field(); i.e. "9.." will drop all 9xx fields, while "952" will only drop 952.  Multiple
#                    entries are allowed.
#   --dropfields2=   Fields to toss out of the MARC record JUST AFTER adding 942 and 952 entries.  This can be in the form used
#                    by MARC::Record->field(); i.e. "9.." will drop all 9xx fields, while "952" will only drop 952.  Multiple
#                    entries are allowed.
#   --static=<marcsub>:<data>       Inserts static data into the named 952 subfield.  Repeatable.
#   --calldefault=<marctag><marcsubs>  Uses the designated field from the MARC as a call, if the item call number is blank.  Repeatable.
#   --pricedefault=<marctag><marcsubs>  Uses the designated field from the MARC as a price, if the item price is blank.  Repeatable.
#   --map=<marcsub>:<filename>     Uses the two-column map in the file to edit the given item subtag
#   --barprefix=     use a term as a barcode prefix
#   --barlength=<n>  make sure the minimum barcode length is <n>, left-padding with zeroes as needed.
#   --pricemap=<filename>  Uses the two-column map in the file to set the price by item type, if one is not already set.
#
#   For mashing in data in a separate item file:
#   --matchpoint=<marc>:<colhead>   Matches a MARC field/subfield to a column in the csv, for use as the matching point.
#   --headerrow=<headerrow>         If the file doesn't contain a header row, use this.
#   --itemcol=<colhead>:<marcsub><~tool><~tool>
#                    Inserts data from the named column into the 952 subfield listed; i.e. BARCODE:p.  Repeatable.  Suffixable by a tool
#                    for data cleanup, which is also repeatable:
#           uc       upper-cases the data, and strips leading and trailing spaces
#           date     Tidies up dates, renders in ISO form
#           date2    Tidies up all-numeric dates, renders in ISO form
#           money    Strips dollar sign, leaves only the numeric part
#           if:<data> Only makes the assignment if <data> is present in the incoming data (and strips it out!)
#           div:<num>  Divides the value by <num>
#                              
#   For mashing embedded item data:
#   --itemtag=<marc>  Designates which field contains items
#   --itemsubfield=<marcsubin>:<marcsubout>~<tool>
#                     Inserts data from the named subfield into the 952 subfield listed.  Repeatable, suffixable with a tool as 
#                     in --itemcol
#

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use Scalar::Util qw(looks_like_number);
use MARC::File::USMARC;
use MARC::File::XML;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_marc_filename  = $NULL_STRING;
my $input_item_filename  = $NULL_STRING;
my $output_marc_filename = $NULL_STRING;
my $output_xml_filename  = $NULL_STRING;
my $codesfile_name       = '/dev/null';
my $matchpoint           = $NULL_STRING;
my $drop_noitems         = 0;
my $barlength            = 0;
my $barprefix            = $NULL_STRING;
my $itemtag              = $NULL_STRING;
my $charset              = 'marc8';
my $csv_delim            = 'comma';
my $header_row           = $NULL_STRING;
my $pricemap_filename    = $NULL_STRING;
my $tally_fields         = 'a,b,8,c,y';
my %pricemap;
my @datamap_filenames;
my %datamap;
my @dropfields;
my @dropfields2;
my @itemcol;
my @itemsub;
my @itemstatic;
my @calldefault;
my @pricedefault;

GetOptions(
    'marc=s'       => \$input_marc_filename,
    'out=s'        => \$output_marc_filename,
    'item=s'       => \$input_item_filename,
    'xml=s'        => \$output_xml_filename,
    'codes=s'      => \$codesfile_name,
    'matchpoint=s' => \$matchpoint,
    'itemtag=s'    => \$itemtag,
    'charset=s'    => \$charset,
    'delimiter=s'  => \$csv_delim,
    'barprefix=s'  => \$barprefix,
    'barlength=i'  => \$barlength,
    'headerrow=s'  => \$header_row,
    'pricemap=s'   => \$pricemap_filename,
    'calldefault=s'=> \@calldefault,
    'pricedefault=s'=> \@pricedefault,
    'map=s'        => \@datamap_filenames,
    'dropfield=s'  => \@dropfields,
    'dropfield2=s' => \@dropfields2,
    'itemcol=s'    => \@itemcol,
    'itemsub=s'    => \@itemsub,
    'static=s'     => \@itemstatic,
    'tally=s'      => \$tally_fields,
    'drop_noitems' => \$drop_noitems,
    'debug'        => \$debug,
);

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                );

for my $var ($input_marc_filename,$output_marc_filename,$output_xml_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if (($input_item_filename ne $NULL_STRING) && ($matchpoint eq $NULL_STRING)){
   croak ("Item CSV present without matchpoint!\n");
}

my ($match_marc,$match_csv);
my $match_marc_subfield;
my $match_tool = $NULL_STRING;
if ($matchpoint ne $NULL_STRING) {
   ($matchpoint,$match_tool) = split(/~/,$matchpoint);
   ($match_marc,$match_csv) = split(/:/,$matchpoint);
   if (!$match_marc || !$match_csv) {
      croak ("Ill-formed matchpoint!\n");
   }
}
my @item_mapping;
foreach my $map (@itemcol) {
   my $col   = $NULL_STRING;
   my $field = $NULL_STRING;
   ($col, $field) = $map =~ /^(.*?):(.*)$/;
   if (($col eq $NULL_STRING) || ($field eq $NULL_STRING)){
      croak ("--itemcol=$map is ill-formed!\n");
   }
   push @item_mapping, {
      'subfield'  => $field,
      'column'    => $col,
   };
}

my @item_tag_mapping;
foreach my $map (@itemsub) {
   if (!$itemtag) {
      croak ("--itemsub specified without --itemtag!\n");
   }
   my ($col, $field) = $map =~ /^(.*?):(.*)$/;
   if (!$col || !$field){
      croak ("--itemsub=$map is ill-formed!\n");
   }
   push @item_tag_mapping, {
      'subfield_in'   => $col,
      'subfield_out'  => $field,
   };
}
 

$debug and print Dumper(@item_mapping);

my @item_static;
foreach my $map (@itemstatic) {
   my ($field, $data) = $map =~ /^(.*?):(.*)$/;
   if (!$field || !$data) {
      croak ("--static=$map is ill-formed!\n");
   }
   push @item_static, {
      'subfield'  => $field,
      'data'      => $data,
   };
}

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

if ($pricemap_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$pricemap_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $pricemap{$data[0]} = $data[1];
   }
   close $mapfile;
}

my %itemhash;
if ($input_item_filename ne $NULL_STRING) {
   my $items_count = 0;
   my $items_dropped = 0;
   print "Loading item data into memory:\n";
   my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $delimiter{$csv_delim} });
   #$debug and print Dumper($csv);
   open my $item_file,'<',$input_item_filename;
   if ($header_row ne $NULL_STRING){
      my @headers = split (/,/,$header_row);
      $csv->column_names(@headers);
   }
   else{
      $csv->column_names($csv->getline($item_file)); 
   }
ITEM:
   while (my $itemline = $csv->getline_hr($item_file)) {
      #last ITEM if ($debug && $j>9);
      $j++;
      print '.'    unless ($j % 10);
      print "\r$j" unless ($j % 100);
      #$debug and print Dumper($itemline);
      if ($itemline->{$match_csv}){
         my ($key,undef) = split (/ /,$itemline->{$match_csv});
         push(@{$itemhash{$key}}, $itemline);
         $items_count++;
      }
      else {
         $items_dropped++;
      }
   }
   close $item_file;
   print "\n$j lines read.\n$items_count items loaded.\n$items_dropped items dropped.\n";
}
#$debug and print Dumper(%itemhash);

my @subfields_possible = qw/a b c d e f g h i j k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9/;
my %tally;
my $xml=0;
my $dropped_itype=0;

my $input_file = IO::File->new($input_marc_filename);
my $batch      = MARC::Batch->new('USMARC',$input_file);
$batch->warnings_off();
$batch->strict_off();
#my $iggy    = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding($charset);
my $dropped_noitems = 0;

print "Processing bibliographic records:\n";
open my $output_file,'>:utf8',$output_marc_filename;
my $output_xml_file =  MARC::File::XML->out($output_xml_filename);

RECORD:
while() {
   last RECORD if ($debug && $i>10);
   my $record;
   my $keep_itype;
   my $keep_issues = 0;
   my $there_are_items = 0;
   eval {$record = $batch->next();};
   if ($@) {
      print "Bogus record skipped.\n";
      next RECORD;
   }
   last RECORD unless ($record);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);

   foreach my $dropfield (@dropfields) {
      foreach my $drop_specific_field ($record->field($dropfield)) {
         $record->delete_field($drop_specific_field);
      }
   }

   my $default_callnumber = $NULL_STRING;
   foreach my $call_try (@calldefault){
      if ($call_try ne $NULL_STRING) {
         my $CNtag = substr($call_try,0,3);
         my $CNsub = substr($call_try,3);
         my $this_field = $record->field($CNtag);
         if ($this_field) {
            $default_callnumber = $this_field->as_string($CNsub);
         }
      }
      last if ($default_callnumber ne $NULL_STRING);
   }

   my $default_price = 0;
   foreach my $try (@pricedefault){
      if ($try ne $NULL_STRING) {
         my $tag = substr($try,0,3);
         my $sub = substr($try,3);
         my $this_field = $record->field($tag);
         if ($this_field) {
            $default_price = $this_field->as_string($sub);
            $default_price =~ s/(\d+(\.[0-9]{2}))/$1/;
            $default_price =~ s/\$//g;
            if (!looks_like_number($default_price)) {
               $default_price = 0;
            }
         }
      }
      last if ($default_price != 0);
   }

   my @matches;
   if ($match_marc) {
      my $match_string;
      if (length($match_marc) > 3 ){
         $match_marc_subfield = substr($match_marc,3,1);
         $match_marc = substr($match_marc,0,3);
      }
      if ($match_marc < 10) {
         my $match_field = $record->field($match_marc);
         if ($match_field) {
            $match_string = $match_field->data();
         }
      }
      else {
         $match_string = $record->subfield($match_marc,$match_marc_subfield);
      }
      if ($match_string) {
         if ($match_tool) {
            $match_string =~ s/($match_tool)//;
         }
         foreach (@{$itemhash{$match_string}}) {
            push (@matches,$_);
         }
      }
   }

MATCH:
   foreach my $match (@matches) {
      $k++;
      my $field = MARC::Field->new('952',' ',' ','9' => 'temp');
      foreach my $map (@item_static) {
         $field->update($map->{'subfield'} => $map->{'data'});
      }

      if ($default_callnumber ne $NULL_STRING) {
            $field->update( 'o' => $default_callnumber);
      }

      foreach my $map (@item_mapping) {
         $debug and print "COL:$map->{'column'}\n";
         if ($match->{$map->{'column'}} ne $NULL_STRING) {
            my $sub = $map->{'subfield'};
            my $data = $match->{$map->{'column'}};
            #$debug and print "$sub: $data\n";
            my $tool;
            my $appendflag;
            if (length($sub) > 2){
               ($sub,$tool) = split (/~/,$sub,2); 
            }
            if (length($sub) > 1) {
               $sub = substr($sub,0,1);
               $appendflag=1;
            }
            if ($tool) {
               foreach my $thistool (split(/~/,$tool)) {
                  $data = _manipulate_data($thistool,$data);
               }
            }
            if ($data ne $NULL_STRING){
               if ($appendflag) {
                  my $olddata = $field->subfield($sub) || $NULL_STRING;
                  my $flddata = $olddata . ' ' . $data;
                  $field->update($sub => $flddata);
               }
               else {
                  $field->update($sub => $data);
               }
            }
         }
      }

      $field->delete_subfield( code => '9' );

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

      if (!$field->subfield('y')) {
         $dropped_itype++;
         next MATCH;
      }

      foreach my $sub (split /,/, $tally_fields){
         if ($field->subfield($sub)) {
            $tally{$sub}{$field->subfield($sub)}++;
         }
      }
      $keep_itype = $field->subfield('y');
      if ($field->subfield('l')) {
         $keep_issues += $field->subfield('l');
      }

      $record->insert_fields_ordered($field);
      $there_are_items = 1;
   }

   if ($itemtag) {
TAG:
      foreach my $field_in ($record->field($itemtag)) {
         $k++;
         my $field = MARC::Field->new('952',' ',' ','9' => 'temp');
         foreach my $map (@item_static) {
            $field->update($map->{'subfield'} => $map->{'data'});
         }

         foreach my $map (@item_tag_mapping) {
            if ($field_in->subfield($map->{'subfield_in'})) {
               my $sub = $map->{'subfield_out'};
               my $tool;
               if (length($sub) > 1){
                  ($sub,$tool) = split (/~/,$sub,2);
               }
               my @data_subs = $field_in->subfield($map->{'subfield_in'});
               foreach my $data (@data_subs){
                  #$debug and print "$sub: $data\n";
                  if ($tool) {
                     foreach my $thistool (split(/~/,$tool)) {
                        $data = _manipulate_data($thistool,$data);
                     }
                  }
                  if ($data ne $NULL_STRING){
                     $field->update($sub => $data);
                  }
               }
            }
         }

         $field->delete_subfield( code => '9' );

         if (!$field->subfield('o') && $default_callnumber ne $NULL_STRING) {
               $field->update( 'o' => $default_callnumber);
         }

         if (!$field->subfield('g') && $default_price ne $NULL_STRING) {
               $field->update( 'g' => $default_price);
         }

         if (!$field->subfield('v') && $default_price ne $NULL_STRING) {
               $field->update( 'v' => $default_price);
         }

         if (!$field->subfield('g') && exists $pricemap{$field->subfield('y')}) {
               $field->update( 'g' => $pricemap{$field->subfield('y')});
         }

         if (!$field->subfield('v') && exists $pricemap{$field->subfield('y')}) {
               $field->update( 'v' => $pricemap{$field->subfield('y')});
         }

         if ($field->subfield('g')==0 && exists $pricemap{$field->subfield('y')}) {
               $field->update( 'g' => $pricemap{$field->subfield('y')});
         }

         if ($field->subfield('v')==0 && exists $pricemap{$field->subfield('y')}) {
               $field->update( 'v' => $pricemap{$field->subfield('y')});
         }

         if ($barprefix ne $NULL_STRING || $barlength > 0) {
            my $curbar = $field->subfield('p');
            my $prefixlen = length($barprefix);
            if (($barlength > 0) && (length($curbar) < $barlength)) {
               my $fixlen = $barlength - $prefixlen;
               while (length ($curbar) < $fixlen) {
                  $curbar = '0'.$curbar;
               }
            
            $curbar = $barprefix . $curbar;
            }
            $field->update( 'p' => $curbar );
         } 

         for my $subfield (@subfields_possible) {
            if ($field->subfield($subfield)) {
               my $oldval = $field->subfield($subfield);
               if ($datamap{$subfield}{$oldval}) {
                  $field->update( $subfield => $datamap{$subfield}{$oldval} );
                  if ($datamap{$subfield}{$oldval} eq 'NULL') {
                     $field->delete_subfield( code => $subfield ,match => qr/^NULL$/ );
                  }
               }
            }
         }

         if (!$field->subfield('y')) {
            $dropped_itype++;
            next TAG;
         }

         foreach my $sub (split /,/, $tally_fields){
            if ($field->subfield($sub)) {
               $tally{$sub}{$field->subfield($sub)}++;
            }
         }
         $keep_itype = $field->subfield('y');
         if ($field->subfield('l')) {
            $keep_issues += $field->subfield('l');
         }

         $record->insert_fields_ordered($field);
         $there_are_items = 1;
      }
   }
     
   if ($keep_itype) {
      if ($datamap{'y'}{$keep_itype}){
         $keep_itype = $datamap{'y'}{$keep_itype};
      }
      my $field = MARC::Field->new('942',' ',' ','c' => $keep_itype, 
                                                 '0' => $keep_issues,
                                  );
      $record->insert_fields_ordered($field);
   }

   foreach my $dropfield (@dropfields2) {
      foreach my $drop_specific_field ($record->field($dropfield)) {
         next if ($drop_specific_field->tag() eq '942');
         next if ($drop_specific_field->tag() eq '952');
         $record->delete_field($drop_specific_field);
      }
   }

   if ($there_are_items || !$drop_noitems) {
      my $output_record;
      eval{ $output_record = $record->as_usmarc(); } ;
      $output_record =~ s/\xBE//g;
      if (length $output_record <= 99999) {
         my $utf8_record = $charset eq 'marc8' ? MARC::Charset::marc8_to_utf8($output_record) : $output_record ;
         if ($utf8_record) {
            print {$output_file} $utf8_record;
            $written++;
         }
      }
      else {
         $output_xml_file->write($record);
         $xml++;
      }
   }
   else {
      $dropped_noitems++;
   }   
}
close $input_file;
close $output_file;
$output_xml_file->close();

print << "END_REPORT";

$i records read.
$written records written.
$xml very long records written to XML file.
$problem records not loaded due to problems.
$dropped_noitems records not output because they had no items attached.
END_REPORT

open my $codes_file,'>',$codesfile_name;
foreach my $kee (sort keys %{ $tally{a} } ){
   print {$codes_file} "REPLACE INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
foreach my $kee (sort keys %{ $tally{b} } ){
   if (!$tally{a}{$kee}) {
      print {$codes_file} "REPLACE INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
   }
}
foreach my $kee (sort keys %{ $tally{y} } ){
   print {$codes_file} "REPLACE INTO itemtypes (itemtype,description) VALUES ('$kee','$kee');\n";
}
foreach my $kee (sort keys %{ $tally{c} } ){
   print {$codes_file} "REPLACE INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','$kee');\n";
}
foreach my $kee (sort keys %{ $tally{8} } ){
   print {$codes_file} "REPLACE INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','$kee');\n";
}
close $codes_file;

print "\nTally results:\n\n";

foreach my $sub (split /,/,$tally_fields) {
   print "\nSubfield $sub:\n";
   foreach my $kee (sort keys %{ $tally{$sub} }) {
      print $kee.':  '.$tally{$sub}{$kee}."\n";
   }
}

exit;

sub _manipulate_data {
   my $tool = shift;
   my $data = shift;
   return $NULL_STRING if ($data eq $NULL_STRING);

   if ($tool eq 'uc') {
      $data = uc $data;
      $data =~ s/^\s+//g;
      $data =~ s/\s+$//g;
   }
   if ($tool eq 'money') {
#      $data =~ s/[^0-9\.]//g;
# comment out next line
#      my $value = $data =~ m/(\d+\.\d\d)/;
if ($data)  {
my $value = substr $data, 2;
      $data = $value;
}
else {
$data = 0;
}
   }
   if ($tool =~ /^if:/) {
      my (undef,$conditional) = split (/:/,$tool, 2);
      if ($data =~ /$conditional/) {
         $data =~ s/$conditional//g;
      }
      else {
         $data = $NULL_STRING;
      }
   }
   if ($tool =~ /^div:/) {
      my (undef,$val) = split (/:/,$tool,2);
      $data = $data / $val;
   }
   if ($tool eq 'date') {
      $data =~ s/ //g;
      my ($month,$day,$year) = $data =~ /(\d+).(\d+).(\d+)/;
      if ($month && $day && $year){
         my @time = localtime();
         my $thisyear = $time[5]+1900;
         $thisyear = substr($thisyear,2,2);
         if ($year < $thisyear) {
            $year += 2000;
         } 
         elsif ($year < 100) {
            $year += 1900;
         }
         $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
         if ($data eq "0000-00-00") {
            $data = $NULL_STRING;
         }
      }
      else {
         $data= $NULL_STRING;
      }
   }
   if ($tool eq 'date2') {
      $data =~ s/ //g;
      if (length($data) >= 8) {
         $debug and print "BEFORE:$data\n";
         my $year  = substr($data,0,4);
         my $month = substr($data,4,2);
         my $day   = substr($data,6,2);
         if ($month && $day && $year){
            $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
         $debug and print "AFTER:$data\n";
         }
         else {
            $data= $NULL_STRING;
         }
      }
      else {
         $data = $NULL_STRING;
      }
   }
   if ($tool eq 'date3') {
      my %months =(
                   JAN => 1, FEB => 2,  MAR => 3,  APR => 4,
                   MAY => 5, JUN => 6,  JUL => 7,  AUG => 8,
                   SEP => 9, OCT => 10, NOV => 11, DEC => 12
                  ); 
      $data = uc $data;
      $data =~ s/,//;
      my ($monthstr,$day,$year) = split(/ /,$data);
      if ($monthstr && $day && $year){
         $data = sprintf "%4d-%02d-%02d",$year,$months{$monthstr},$day;
      }
      else {
         $data= $NULL_STRING;
      }
   }
   return $data;
}
