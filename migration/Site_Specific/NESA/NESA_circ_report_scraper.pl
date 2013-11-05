#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -Joy Nelson
#
#  this script is designed to read a 'text style' Circulation report that has been 
#  fed into a csv file.  It pulls borrowers systemid, itembarcode and datedue from the report
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Encode;
use Getopt::Long;
use Text::CSV;
use Text::CSV::Simple;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $csv=Text::CSV->new( { binary=>1} );

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
my $i=0;
my $written=0;

my %thisrow;
my @charge_fields= qw{ patron itembar datedue };

open my $infl,"<",$infile_name;
open my $outfl,">",$outfile_name || die ('problem opening $outfile_name');
for my $j (0..scalar(@charge_fields)-1){
   print $outfl $charge_fields[$j].',';
}
print $outfl "\n";

my $NULL_STRING = '';
my $borr;
my $itembar;
my $datedue;

LINE:
while (my $line=$csv->getline($infl)){
   last LINE if ($debug && $written >50);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   my @data = @$line;

   next LINE if $data[0] eq q{};
   next LINE if $data[0] =~ /^Status/;
   next LINE if $data[0] =~ /^BOOKS: /;
   next LINE if $data[0] =~ /^  /;
   next LINE if $data[0] =~ /^Subtotal/;
   next LINE if $data[0] =~ /^Total/;
   next LINE if $data[0] =~ /^AUDIOVISUAL/;
#print "@data\n";

   my @circdata = split(/ +/,$data[0]);
#print "$circdata[0],$circdata[1], $circdata[2], $circdata[3], $circdata[4], $circdata[5], $circdata[6], $circdata[7]\n";

   if ( $circdata[0] eq 'ITEM') {
          $borr = $circdata[5];
          $itembar = $circdata[3];
	  $datedue = format_the_date($circdata[7]);
	  print $outfl $borr.','.$itembar.','.$datedue."\n";
	  $written++;
       next LINE;
	  }
}

close $infl;
close $outfl;

print "\n\n$i lines read.\n$written charges written.\n";
exit;

sub format_the_date {
   my $the_date=shift;
   $the_date =~ s/\///g;
   my $year  = substr($the_date,4,2);
   my $month = substr($the_date,0,2);
   my $day   = substr($the_date,2,2);
   $year = 2000 + $year;
   if ($month && $day && $year){
       $the_date = sprintf "%4d-%02d-%02d",$year,$month,$day;
       if ($the_date eq "0000-00-00") {
           $the_date = $NULL_STRING;
       }
    }
   else {
         $the_date= $NULL_STRING;
   }
   return $the_date;
}

