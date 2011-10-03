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
#      MARC_Number,     Create_Date,  ITEM_NUM,    Temp_Bar_Code,     Create_User_ID,
#      TEMP_ITEM_TYPE,  Temp_Author,  Temp_Title,  Temp_Call_Number
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
my $mapfile_name = "";
my $loccodefile_name = "";
my $itemfile_name = "";
my $static_itype = "UNKNOWN";

GetOptions(
    'in:s'     => \$infile_name,
    'out:s'    => \$outfile_name,
    'items=s'  => \$itemfile_name,
    'map=s'    => \$mapfile_name,
    'loccode=s' => \$loccodefile_name,
    'itype=s'   => \$static_itype,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq q{}) || ($outfile_name eq q{}) ||
    ($itemfile_name eq q{}) || ($mapfile_name eq q{}) ||
    ($loccodefile_name eq q{})){
   print "You're missing something.\n";
   exit;
}

my %branchmap;
my %typemap;
my %locmap;
my $mapcsv = Text::CSV_XS->new();
open my $mapfile,"<$mapfile_name";
while (my $row = $mapcsv->getline($mapfile)){
   my @data = @$row;
   $branchmap{$data[0]}=$data[1];
   $typemap{$data[0]}=$data[2];
   $locmap{$data[0]}=$data[3];
}
close $mapfile;

my %loccodemap;
open my $codefile,"<",$loccodefile_name;
while (my $row = $mapcsv->getline($codefile)){
   my @data = @$row;
   $loccodemap{$data[0]} = $data[3];
}
close $codefile;
$debug and print Dumper(%loccodemap);
$debug and exit;

my $written=0;
               
my %barcode_counts;
my $csv = Text::CSV_XS->new();
open my $in,"<",$infile_name;
open my $out,">:utf8",$outfile_name;
my $line = readline($in);
chomp $line;
$line =~ s///g;
$debug and print "$line\n";
my @columns = split (/\t/,$line);

RECORD:
while (my $line=$csv->getline($in)){
   last RECORD if ($debug and $written>5);
   $i++;
   print '.' unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data=@$line;
   $debug and print Dumper(@data);
   my $rec = MARC::Record->new();
   $rec->leader('     nam a22        4500');

   my $barcode=$data[3];
   my ($month,$day,$year) = split (/\//,$data[1]);
   my $create_date = sprintf "%4d-%02d-%02d",$year,$month,$day;
   my $itemnum = $data[2];

   my @matches = qx{grep "^$itemnum," $itemfile_name};

   my $csv = Text::CSV_XS->new( {binary => 1});
   $csv->parse($matches[0]);
   my @line=$csv->fields();
   $debug and print Dumper(@line);

   my $fld245 = MARC::Field->new('245',' ',' ','a'=> $line[16]);
   $rec->insert_grouped_field($fld245);

   my $loc = $locmap{ $loccodemap{ $line[23] } };      
   my $branch = $branchmap{ $loccodemap{ $line[23] } };

   my $fld942 = MARC::Field->new( 942,' ',' ','c' => $static_itype,
                                              'n' => 1,
                                );
   $rec->insert_grouped_field($fld942);

   my $fld952 = MARC::Field->new( 952,' ',' ',
                                   'a' => $branch,
                                   'b' => $branch,
                                   'p' => $barcode,
                                   'y' => $static_itype,
                                   'd' => $create_date,
                                );
   $rec->insert_grouped_field($fld952);

   $debug and print $rec->as_formatted()."\n\n";
   print {$out} $rec->as_usmarc();
   $written++;
}

close $out;
close $in;

print "\n\n$i records read.\n$written records written.\n";
