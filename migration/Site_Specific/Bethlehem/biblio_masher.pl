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
#   -formatted CSV files with the following column heads, in THIS order:
#      ISBN/ISSN             CALL #                BARCODE              TITLE              AUTHOR
#      YEAR
#
# DOES:
#   -nothing
#
# CREATES:
#   -MARC file
#
# REPORTS:
#   -count of records read
#   -count of MARCs built and output

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use MARC::Record;
use MARC::Field;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $infile_name   = q{};
my $outfile_name  = q{};


GetOptions(
    'in:s'     => \$infile_name,
    'out:s'    => \$outfile_name,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq q{}) || ($outfile_name eq q{})){
   print "You're missing something.\n";
   exit;
}

my $written=0;
my %leaders=(
               'BOOK'           => '     nam a22        4500',
            );

my %barcode_counts;
my $csv = Text::CSV_XS->new({binary => 1});
open my $in,"<",$infile_name;
open my $out,">:utf8",$outfile_name;
$csv->column_names($csv->getline($in));


RECORD:
while (my $line=$csv->getline_hr($in)){
   last RECORD if ($debug and $written>20);
   $i++;
   print '.' unless ($i % 10);
   print "\r$i" unless ($i % 100);
   next RECORD if (($line->{TITLE} eq q{}) || ($line->{BARCODE} eq q{}));
   my $rec = MARC::Record->new();
   $rec->leader($leaders{BOOK});
   my $fld245 = MARC::Field->new( 245,' ',' ','a' => $line->{TITLE} ); 
   $rec->insert_grouped_field($fld245);

   if ($line->{AUTHOR} ne q{}) {
      my $fld = MARC::Field->new( 100,' ',' ','a' => $line->{AUTHOR} );
      $rec->insert_grouped_field($fld);
   }
    
   
   my $fld260 = MARC::Field->new( 260,' ',' ','8' => 1); 
   my $valid_260=0;

   my $done_008; 
   if ($line->{YEAR} ne q{}){
      $fld260->update('c' => $line->{YEAR} );
      $valid_260=1;
      $line->{YEAR}=~ m/(\d\d\d\d)/;
      my $year_only = $1;
      if ($year_only) {
         my $fld = MARC::Field->new('008','      s'.$year_only);
         $rec->insert_fields_ordered($fld);
         $done_008 = 1;
      }
   }

   if ($valid_260){
      $fld260->delete_subfield(code => '8');
      $rec->insert_grouped_field($fld260);
   }

   if ($line->{'ISBN/ISSN'} ne q{}){
      my $fld = MARC::Field->new( '020',' ',' ','a' => $line->{'ISBN/ISSN'} );
      $rec->insert_grouped_field($fld);
   }

   my $fld = MARC::Field->new( 952,' ',' ',
                                   'a' => 'MAIN',
                                   'b' => 'MAIN',
                                   'p' => $line->{BARCODE} );
   if ($line->{'CALL #'} ne q{}){
         $fld->update('o' => $line->{'CALL #'} );
   }
   $rec->insert_grouped_field($fld);

   $debug and print $rec->as_formatted()."\n\n";
   print {$out} $rec->as_usmarc();
   $written++;
}

close $out;
close $in;

print "\n\n$i records read.\n$written records written.\n";

exit;
