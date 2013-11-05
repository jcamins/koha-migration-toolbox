#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
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
use Date::Calc qw(Add_Delta_Days);
use C4::Context;
use C4::Items;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename      = $NULL_STRING;
my $branch_map_filename = $NULL_STRING;
my $borrower_map_filename = $NULL_STRING;
my $biblio_map_filename   = $NULL_STRING;
my %branch_map;
my %borrower_map;
my %biblio_map;

GetOptions(
    'in=s'               => \$input_filename,
    'branch_map=s'       => \$branch_map_filename,
    'borrower_map=s'     => \$borrower_map_filename,
    'biblio_map=s'       => \$biblio_map_filename,
    'debug'              => \$debug,
    'update'             => \$doo_eet,
);

for my $var ($input_filename, $borrower_map_filename, $biblio_map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

Readonly my $FIELD_SEP    => chr(254);
Readonly my $SUBFIELD_SEP => chr(253);
my $dbh = C4::Context->dbh();
my $insert_sth = $dbh->prepare("INSERT INTO reserves
                                (biblionumber, borrowernumber, branchcode, reservedate, expirationdate, constrainttype, priority) 
                                VALUES (?, ?, ?, ?, ?, 'a', 0)");

if ($branch_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$branch_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $map_file;
}

if ($borrower_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$borrower_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      if ($data[0] ne $NULL_STRING) {
         $borrower_map{$data[0]} = $data[1];
      }
   }
   close $map_file;
}

if ($biblio_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$biblio_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      if ($data[0] ne $NULL_STRING) {
         $biblio_map{$data[0]} = $data[1];
      }
   }
   close $map_file;
}

open my $input_file,'<',$input_filename;
RECORD:
while (my $line = readline($input_file)){
   #last RECORD if ($debug and $i>10);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   #$debug and print "\n$i: ";
   
   chomp $line;
   $line =~ s///g;
   my @columns = split /$FIELD_SEP/,$line;

   next RECORD if $debug && $columns[0] ne "167052";
 
   my $biblio = $biblio_map{$columns[0]};
   if (!$biblio ) {
      print "Biblio $columns[1] not found.\n";
      $problem++;
      next RECORD; 
   }
   my @borrowers      = split /$SUBFIELD_SEP/,$columns[1];
   my @dates_entered  = split /$SUBFIELD_SEP/,$columns[2];
   my @dates_expiring = split /$SUBFIELD_SEP/,$columns[5];
   my @branchcodes    = split /$SUBFIELD_SEP/,$columns[7];

BORROWER:
   for my $j (0..scalar(@borrowers)-1) {
      my $borrower = $borrower_map{$borrowers[$j]};
      if (!$borrower) {
         print "Borrower $borrowers[$j] not found.\n";
         $problem++;
         next BORROWER;
      }

      my $reservedate = _process_date($dates_entered[$j]);
      my $expiredate  = _process_date($dates_expiring[$j]);
      my $branch      = $branchcodes[$j];

      if (exists $branch_map{$branch} ) {
         $branch = $branch_map{$branch};
      }

      $debug and print "PATRON: $borrower BIBLIO: $biblio  BRANCH: $branch PLACED $reservedate EXPIRES $expiredate\n";
      if ($doo_eet) {
         $insert_sth->execute($biblio, $borrower, $branch, $reservedate, $expiredate);
      }
      $written++;
   }
}
close $input_file;

print "\n\n$i lines read.\n$written holds written.\n$problem problems encountered.\n";

exit;

sub _process_date {
   my $datein = shift;
   return undef if !$datein;
   return undef if $datein eq q{};
   return undef if $datein < 0;
   my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$datein);
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
