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
#      Accession_number,     Record_Type,          Location,            Call number,       Call number-pamphlet, 
#      Bimonthly volume,     Author,               Responsibility note, Book Title,        Article Title, 
#      Title - All,          Edition,              Series,              Year - All,        Publisher,
#      Year of Publication,  Journal,              Journal Volume,      Journal date-year, Pagination,
#      Copies,               Volumes,              Price,               ISBN,              ISSN,
#      Main Heading,         Subject,              New subject,         Abstract,          Notes,
#      Added by,             Item Status,          Date cataloged,      Date modified,     Order date,
#      Book status,          Entry number,         City - State,        Title main entry,  Title sort,
#      Volume info,          Place of Publication, Main entry Sort,     Local note,        Full text URL,
#      Full text URLcaption, Related URL,          Related URL caption, Circulating copy,  ISBN-13
#      Linkcheck
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of records read
#   -count of various field values

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
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq q{})){
   print "You're missing something.\n";
   exit;
}

my %record_types;
my %locations;
open my $in,"<",$infile_name;
my $line = readline($in);

RECORD:
while (my $line=readline($in)){
   $i++;
   print '.' unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $line =~ s///g;
   my @data=split(/\t/,$line);
   next RECORD if (scalar (@data)==1);
   if (scalar(@data) < 51){
      my $err = "problem record $i\nOld size: ".scalar(@data).'   ';
      $i++;
      my $line2 = readline($in);
      $line .= ' '.$line2;
      @data=split(/\t/,$line);
      $err .= "New size: ".scalar(@data)."\n";
      $debug and print $err if (scalar(@data) != 51);
      next RECORD if (scalar(@data) != 51);
   }
   $record_types{$data[1]}++; 
   foreach my $loc (split(/\|/,$data[2])){
      $locations{$loc}++;
   }
}

close $in;

print "\n\n$i records read.\n\n";

print "Counts by RECORD TYPE:\n";
foreach my $kee (sort keys %record_types){
   print $kee.':  '.$record_types{$kee}."\n";
}

print "\nCounts by LOCATION:\n";
foreach my $kee (sort keys %locations){
   print $kee.':  '.$locations{$kee}."\n";
}
