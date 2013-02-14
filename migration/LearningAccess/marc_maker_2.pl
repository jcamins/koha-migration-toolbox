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
#   -database credentials
#   -output filename
#   -which table to extract
#
# DOES:
#   -nothing
#
# CREATES:
#   -MARC file
#
# REPORTS:
#   -count of records written.

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;

use DBI;
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

my $database_name   = $NULL_STRING;
my $database_user   = $NULL_STRING;
my $database_pass   = $NULL_STRING;
my $database_table  = $NULL_STRING;
my $output_filename = $NULL_STRING;

GetOptions(
    'db=s'     => \$database_name,
    'user=s'   => \$database_user,
    'pass=s'   => \$database_pass,
    'table=s'  => \$database_table,
    'out=s'    => \$output_filename,
    'debug'    => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($database_name,$database_user,$database_pass,$database_table,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

open my $output_file,'>:utf8',$output_filename;
my $dbh = DBI->connect("dbi:mysql:$database_name:localhost:3306",$database_user,$database_pass);
my $marc_list = $dbh->prepare("SELECT DISTINCT marcnumber FROM $database_table ORDER BY marcnumber");
my $tag_list = $dbh->prepare("SELECT field,data FROM $database_table WHERE marcnumber=? ORDER BY datarow");

$marc_list->execute();
RECORD:
while (my $record_number=$marc_list->fetchrow_array()) {
   last RECORD if ($debug and $written >1);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $record=MARC::Record->new();
   $tag_list->execute($record_number);
TAG:
   while (my $tag=$tag_list->fetchrow_hashref()) {
      my $tag_number = sprintf("%03d",$tag->{field});
      if ($tag->{field} == 0) {    #leader!
         $record->leader($tag->{data});
         next TAG;
      }
      if ($tag->{field} < 10) {   #encoded data
         my $field=MARC::Field->new( $tag_number, $tag->{data});
         $record->append_fields($field);
         next TAG;
      }
      if ($tag->{field} == 35 and $tag->{data} =~ m/^/) {   #strange 035s!
         my $field=MARC::Field->new( '035',' ',' ','9' => 'oy');
         foreach my $sub (split //, substr($tag->{data},1)) {
            my $subcode=substr($sub,0,1);
            my $subdata=substr($sub,1);
            $field->add_subfields( $subcode => $subdata );
         }
         $field->delete_subfield( code=>'9',pos=>0 );
         $record->append_fields($field);
         next TAG;
      }
      if ($tag->{field} == 35 and $tag->{data} !~ m/^/) {   # VERY strange 035s!
         my $field=MARC::Field->new( '035',' ',' ','a' => $tag->{data});
         $record->append_fields($field);
         next TAG;
      }
      # everything else!
      next TAG if (length($tag->{data})<4);
      my ($indicators,$data_string) = split //, $tag->{data},2;
      if (!$data_string) {
         print Dumper($tag);
      }
      my $ind1 = ' ';
      my $ind2 = ' ';
      if (length($indicators) == 2) {
         $ind1 = substr($indicators,0,1);
         $ind2 = substr($indicators,1,1);
      }
      if (length($indicators) == 1) {
         $ind1 = substr($indicators,0,1);
      }
      my $field=MARC::Field->new( $tag_number,$ind1,$ind2,'9' => 'oy');
SUB:
      foreach my $sub (split //, $data_string) {
         next SUB if (length($sub) < 2);
         my $subcode=substr($sub,0,1);
         my $subdata=substr($sub,1);
         $field->add_subfields( $subcode => $subdata );
      }
      $field->delete_subfield( code=>'9',pos=>0 );
      $record->append_fields($field);
   }
   $record->encoding( 'UTF-8' );
   $debug and say $record->as_formatted();
   print {$output_file} $record->as_usmarc();
   $written++;
}
close $output_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not written due to problems.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
