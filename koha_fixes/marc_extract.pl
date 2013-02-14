#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#   - edited by Joy Nelson to extract marc for ebooks with only an 856$u to identify
#
#---------------------------------

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use C4::Context;
use MARC::Record;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};
my $start_time             =  time();

my $debug   = 0;
my $doo_eet = 0;
my $written = 0;
my $problem = 0;

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my %queries = (
   "01-biblio.mrc" => "SELECT marc FROM biblioitems where (ExtractValue (marcxml, '\/\/datafield[\@tag=\"856\"]\/subfield[\@code>=\"u\"]') like '%Netlibrary%'",
);

my $dbh = C4::Context->dbh();

QUERY:
foreach my $key (sort keys %queries) {
   say "Performing query for $key:";
   my $sth = $dbh->prepare($queries{$key});
   $sth->execute();
   if ($sth->err) {
      next QUERY;
   }
   open my $output_file,'>:utf8',$key;
   my $i = 0;
   if ($key =~ /\.mrc$/) {   #This file needs to be output in MARC!
MARC_RECORD:
      while (my @line = $sth->fetchrow_array()) {
         $i++;
         print "."    unless ($i % 10);
         print "\r$i" unless ($i % 100);
         my $marc;
         eval {$marc = MARC::Record->new_from_usmarc($line[0]); };
         if ($@){
            say "bogus record skipped";
            next MARC_RECORD;
         }
         print {$output_file} $marc->as_usmarc();
      }  #MARC_RECORD
      say "";
      say "$i records output.";
   }
   else {  #This file is a CSV!
      my @columns = @{$sth->{NAME}};
      foreach my $column (@columns){
         print {$output_file} "$column,";
      }
      print {$output_file} "\n";
RECORD:
      while (my @line = $sth->fetchrow_array()){
         $i++;
         print "."    unless ($i % 10);
         print "\r$i" unless ($i % 100);
         for my $k (0..scalar(@line)-1){
            if (!defined $line[$k]) {
               $line[$k] = $NULL_STRING;
            }
            $line[$k] =~ s/"/'/g;
            if ($line[$k] =~ /,/ || $line[$k] =~ /\n/ || $line[$k] =~ //){
               print {$output_file} '"'.$line[$k].'"';
            }
            else{
               print {$output_file} $line[$k];
            }
            print {$output_file} ',';
         }
         print {$output_file} "\n";
      }  #RECORD
      say "";
      say "$i records output.";
   }
}  #QUERY

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
