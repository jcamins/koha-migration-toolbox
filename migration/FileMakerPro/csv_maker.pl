#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";

GetOptions(
    'in=s'            => \$infile_name,
    'out=s'           => \$outfile_name,
    'debug'           => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $i=0;
my $written;
my %thisrec = ();

open my $in,"<$infile_name";
open my $out,">:utf8",$outfile_name;
print {$out} "ignoreme,recnum,";

HEADER:
while (my $line = readline($in)) {
   next HEADER if ($line =~ m/^<\?xml/);
   last HEADER if ($line =~ m/<\/METADATA>/);
   $debug and print $line;
   $line =~ m/NAME="(.+?)" /;
   my $thistag = $1;
   $debug and print $thistag;
   print {$out} $thistag.',';
}

print {$out} "\n";

RECORD:
while (my $line = readline($in)) {
   last RECORD if ($debug && $written>9);
   chomp $line;
   $i++;
   print "." unless $i % 10;
   print "\r$i" unless $i % 100;
   my @data = split(/\|/,$line);
   for my $k (0..scalar(@data)-1){
      if ($data[$k] =~ m/^"(\d+?)"$/){
         $data[$k] = $1;
      }
      $data[$k] =~ s/\"/\\\"/g;
      if ($data[$k] =~ /,/){
         print {$out} '"'.$data[$k].'",';
      }
      else{
         print {$out} $data[$k].',';
      }
   }
   print {$out} "\n"; 
   $written++;
}
close $out;
close $in;

print "\n\n$i lines read.\n$written lines written.\n";

exit;
