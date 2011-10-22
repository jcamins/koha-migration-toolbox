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

use MARC::File::USMARC;
use MARC::Record;
use MARC::Batch;
use MARC::Charset;
use Date::Calc qw(Add_Delta_Days);

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $written = 0;
my $problem = 0;

my $input_filename               = $NULL_STRING;
my $item_filename                = $NULL_STRING;
my $output_filename              = $NULL_STRING;
my $location_branch_map_filename = $NULL_STRING;
my $collcode_map_filename        = $NULL_STRING;

my %branch_map;
my %collcode_map;

my $default_itemtype = 'UNKNOWN';
my $default_branch   = 'UNKNOWN';
my $use_hash         = 0;
my $drop_noitem      = 0;

GetOptions(
    'in=s'             => \$input_filename,
    'item=s'           => \$item_filename,
    'out=s'            => \$output_filename,
    'loc_branch_map=s' => \$location_branch_map_filename,
    'collcode_map=s'   => \$collcode_map_filename,
    'def_itemtype=s'   => \$default_itemtype,
    'def_branch=s'     => \$default_branch,
    'use_hash'         => \$use_hash,
    'drop_noitem'      => \$drop_noitem,
    'debug'            => \$debug,
);

Readonly my $field_sep    => chr(254);
Readonly my $subfield_sep => chr(253);

for my $var ($input_filename,$item_filename,$output_filename,$default_itemtype,$default_branch) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

if ($location_branch_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$location_branch_map_filename;
   while (my $line = $csv->getline($map_file)) {
      my @columns = @$line;
      $branch_map{$columns[0]} = $columns[1];
   }
   close $map_file;
}

if ($collcode_map_filename ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$collcode_map_filename;
   while (my $line = $csv->getline($map_file)) {
      my @columns = @$line;
      $collcode_map{$columns[0]} = $columns[1];
   }
   close $map_file;
}

my %item_hash;
if ($use_hash) {
   print "Loading item data into memory.\n";
   open my $item_file,'<',$item_filename;
   while (my $line = readline($item_file)) {
      $i++;
      print '.'    unless ($i % 10);
      print "\r$i" unless ($i % 100);
      chomp $line;
      my @columns = split /$field_sep/,$line;
      push (@{$item_hash{$columns[1]}}, $line);
   }
   close $item_file;
   print "\n$i items loaded.\n";
}

my $file_handle = IO::File->new($input_filename);
my $batch       = MARC::Batch->new('USMARC',$file_handle);
my $iggy        = MARC::Charset::ignore_errors(1);
my $setting     = MARC::Charset::assume_encoding('marc8');
$batch->warnings_off();
$batch->strict_off();

my %itemtypes;
my %branches;
my %locations;
my %collcodes;
my $no_items   = 0;

$i = 0;

open my $output_file,'>',$output_filename;
RECORD:
while () {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $record = $batch->next();
   if ($@){
      print "Bogusness skipped\n";
      next RECORD;
   }
   last RECORD unless ($record);

   foreach my $field($record->field('949')) {
      $record->delete_field($field);
   }
   foreach my $field($record->field('999')) {
      $record->delete_field($field);
   }

   my $biblio_key = $record->subfield('998','a');

   my $price = 0;
   if ($record->subfield("350","a")){
      $price = $record->subfield("350","a");
      #$price =~ s/\D\.]//;
      $price =~ s/(\d+(\.[0-9]{2}))/$1/;
      $price =~ s/\$//g;
   }

   my @matches;
   if ($use_hash){
      foreach (@{$item_hash{$biblio_key}}){
         push(@matches,$_);
      }
   }
   else{
      @matches = qx{grep "$biblio_key" $item_filename};
   } 

   if (scalar(@matches) == 0) {
      $no_items++;
      next RECORD if ($drop_noitem);
   }

MATCH:
   foreach my $match (@matches) {
      my @columns = split /$field_sep/,$match;
      next MATCH if ($columns[1] ne $biblio_key);

      $j++;
      my %item;
      $item{barcode} = $NULL_STRING;
      $item{itype}   = $default_itemtype;
      $item{branch}  = $default_branch;

      $item{barcode} = $columns[0];

      my @subcolumns = split /$subfield_sep/,$columns[2];
      if ($subcolumns[0]){
         my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$subcolumns[0]);
         $item{date_acquired}   = sprintf "%4d-%02d-%02d",$year,$month,$day;
      }

      $item{itype} = $columns[3];

      @subcolumns = split /$subfield_sep/,$columns[4];
      if (defined $subcolumns[0]) {
         $item{checkouts} = $subcolumns[0];
      }
  
      $item{itemcallnumber} = $columns[5];
      $item{branch}         = $columns[6];
      $item{location}       = $columns[7];

      if ($location_branch_map_filename ne $NULL_STRING) {
         $item{branch}   = $branch_map{$columns[7]};
         $item{location} = undef;
      }

      if (defined $columns[10]) {
         @subcolumns = split /$subfield_sep/,$columns[10];
         if (defined $subcolumns[0]) {
            my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$subcolumns[0]);
            $item{last_borrowed}   = sprintf "%4d-%02d-%02d",$year,$month,$day;
         }
      }

      if (defined $columns[15]) {
         $item{collcode} = $columns[15];
         if ($collcode_map{ $item{collcode} }) {
            $item{collcode} = $collcode_map{ $item{collcode} };
         }
      }

      if (defined $columns[16]) {
         $item{copy_number} = $columns[16];
      }

      $item{price} = $price;
      if (defined $columns[17]) {
         $item{price} = $columns[17];
      }

      if (defined $columns[20]){
         @subcolumns = split /$subfield_sep/, $columns[20];
         foreach my $subcolumn (@subcolumns){
            $item{note} .= ' '.$subcolumn;
         }
      }
 
      if (defined $columns[21]) {
         $item{nonpublic_note} = $columns[21];
      }

      if ($item{barcode} eq $NULL_STRING 
          || $item{branch} eq $NULL_STRING
          || $item{itype}  eq $NULL_STRING) {
         $problem++;
         next MATCH;
      }

      $branches{$item{branch}}++;
      $itemtypes{$item{itype}}++;
      if ($item{location}) {
         $locations{$item{location}}++;
      }
      if ($item{collcode}) {
         $collcodes{$item{collcode}}++;
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
      $field->update( 't' => $item{copy_number} )    if ($item{copy_number});
      $field->update( 'x' => $item{nonpublic_note} ) if ($item{nonpublic_note});
      $field->update( 'z' => $item{note} )           if ($item{note});
      $field->update( '8' => $item{collcode} )       if ($item{collcode});

      $record->insert_fields_ordered($field);
   }

   print {$output_file} $record->as_usmarc();
   $written++;
}
close $output_file;

print "\n$i records read\n$j items found.\n$problem problem items not added.\n";

open my $sql_file,'>','biblio_codes.sql';
print "\nRESULTS BY BRANCH:\n";
foreach my $kee (sort keys %branches){
   print $kee.":  ".$branches{$kee}."\n";
   print {$sql_file} "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print "\nRESULTS BY ITEM TYPE:\n";
foreach my $kee (sort keys %itemtypes){
   print $kee.":  ".$itemtypes{$kee}."\n";
   print {$sql_file} "INSERT INTO itemtypes (itemtype,description) VALUES ('$kee','$kee');\n";
}
print "\nRESULTS BY LOCATION:\n";
foreach my $kee (sort keys %locations){
   print $kee.":  ".$locations{$kee}."\n";
   print {$sql_file} "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('LOC','$kee','$kee');\n";
}
print "\nRESULTS BY COLLECTION CODE:\n";
foreach my $kee (sort keys %collcodes){
   print $kee.":  ".$collcodes{$kee}."\n";
   print {$sql_file} "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CCODE','$kee','$kee');\n";
}
close $sql_file;

exit;
