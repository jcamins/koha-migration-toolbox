#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -<author>
#
#---------------------------------
#
# EXPECTS:
#   -formatted CSV files with the following column heads, in any order:
#      SetAccNo,Class4,Class7,Author,Title,Extent,SubjectHeading,Abstract
#   -journal title
#   -journal static call number
#    
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
my $journal_title = q{};
my $journal_call  = q{};


GetOptions(
    'in:s'     => \$infile_name,
    'out:s'    => \$outfile_name,
    'title:s'  => \$journal_title,
    'call:s'   => \$journal_call,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq q{}) || ($outfile_name eq q{}) || ($journal_title eq q{}) || ($journal_call eq q{})){
   print "You're missing something.\n";
   exit;
}

my $written=0;
my %barcode_counts;
my $csv = Text::CSV_XS->new({binary => 1,sep_char => "\t"});
open my $in,"<",$infile_name;
open my $out,">:utf8",$outfile_name;
my $line = readline($in);
chomp $line;
$line =~ s/\"//g;
$debug and print "$line\n";
$csv->column_names(split (/\t/,$line));

RECORD:
while (my $hr=$csv->getline_hr($in)){
   last RECORD if ($debug and $written>0);
   $debug and print Dumper($hr);
   $i++;
   print '.' unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $rec = MARC::Record->new();
   my $fld952 = MARC::Field->new( 952,' ',' ',
                                   'a' => 'JUNGNYC',
                                   'b' => 'JUNGNYC',
                                   'y' => 'ARTICLE',
                                   'o' => $journal_call,
                                   '7' => '1',
                                   '8' => 'PPER');

   my $tempbarcode = $journal_call.'-'.$i;
   my $barcode = $hr->{SetAccNo} || $tempbarcode;
   my $orig_barcode = $barcode;
   if (exists $barcode_counts{$orig_barcode}){
      $barcode = $orig_barcode.'-'.$barcode_counts{$orig_barcode};
      $barcode_counts{$orig_barcode}++;
   }
   else{
      $barcode_counts{$orig_barcode}=1;
   }
   $fld952->update( 'p' => $barcode);
   $rec->insert_grouped_field($fld952);

   if ($hr->{Author}){
      my $fld = MARC::Field->new( 100,' ',' ',
                                   'a' => $hr->{Author});
      $rec->insert_grouped_field($fld);
   }

   if ($hr->{Title}){
      my $fld = MARC::Field->new( 245,' ',' ',
                                   'a' => $hr->{Title});
      $rec->insert_grouped_field($fld);
   }

   if ($hr->{Abstract}){
      my $fld = MARC::Field->new( 505,'0',' ',
                                   'a' => $hr->{Abstract});
      $rec->insert_grouped_field($fld);
   }

   if ($hr->{SubjectHeading}){
      foreach my $subj (split (/\|/,$hr->{SubjectHeading})){
         my $fld = MARC::Field->new( 650,'0',' ',
                                      'a' => $subj);
         $rec->insert_grouped_field($fld);
      }
   }

   my $subg = $hr->{Class4}.', Volume/Issue '.$hr->{Class7}.', '.$hr->{Extent};
   my $fld773 = MARC::Field->new( 773,'0',' ',
                                   't' => $journal_title,
                                   'g' => $subg);
   $rec->insert_grouped_field($fld773);
   $debug and print $rec->as_formatted();
   print {$out} $rec->as_usmarc();
   $written++;
}

close $out;
close $in;

print "\n\n$i records read.\n$written records written.\n";
