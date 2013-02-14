#!/usr/bin/perl

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

use DBI;

use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Members;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $database_name   = $NULL_STRING;
my $database_user   = $NULL_STRING;
my $database_pass   = $NULL_STRING;
my $output_filename = $NULL_STRING;

GetOptions(
    'db=s'     => \$database_name,
    'user=s'   => \$database_user,
    'pass=s'   => \$database_pass,
    'out=s'    => \$output_filename,
    'debug'             => \$debug,
);

for my $var ($database_name,$database_user,$database_pass,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my @borrower_fields = qw /cardnumber phone mobile fax phonepro/;
open my $output_file,'>',$output_filename;

foreach my $field (@borrower_fields) {
   print {$output_file} "$field,";
}

my $dbh = DBI->connect("dbi:mysql:$database_name:localhost:3306",$database_user,$database_pass);

my $borrower_sth = $dbh->prepare("SELECT patronnumber, patroncardnumber from patroncard where primarycard=1");
my $sth_6 = $dbh->prepare("SELECT phonetype,patronphone FROM patronphone WHERE patronnumber=?");

$borrower_sth->execute();
RECORD:
while (my $record=$borrower_sth->fetchrow_hashref()) {
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my %this_borrower;
   my $patronnumber = $record->{patronnumber};
   $this_borrower{cardnumber} = $record->{patroncardnumber};

   $sth_6->execute($patronnumber);
   while (my $this_phonerec = $sth_6->fetchrow_hashref()) {
      $this_borrower{phonepro} = $this_phonerec->{patronphone} if ($this_phonerec->{phonetype} eq 'work');
      $this_borrower{mobile}   = $this_phonerec->{patronphone} if ($this_phonerec->{phonetype} eq 'cell');
      $this_borrower{phone}    = $this_phonerec->{patronphone} if ($this_phonerec->{phonetype} eq 'home' ||
                                                                   $this_phonerec->{phonetype} eq 'local');
   }

   foreach my $field (@borrower_fields) {
      if ($this_borrower{$field}) {
         $this_borrower{$field} =~ s/\"/'/g;
         $this_borrower{$field} =~ s///g;
         $this_borrower{$field} =~ s/\n//g;
         if ($this_borrower{$field} =~ /,/){
            print {$output_file} '"'.$this_borrower{$field}.'"';
         } else {
            print {$output_file} $this_borrower{$field};
         }
      }
      print {$output_file} ',';
   }
   print {$output_file} "\n";
}
close $output_file;

print "\n$i records written.\n";

exit;

