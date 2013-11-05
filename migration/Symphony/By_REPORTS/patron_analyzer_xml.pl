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
#   -input XML from Symphony
#
# DOES:
#   -nothing
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of borrowers read
#   -counts of tags used

use autodie;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Modern::Perl;
use Readonly;
use Text::CSV_XS;
use XML::Simple;

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

my $input_filename  = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'debug'    => \$debug,
);

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}
my %tags = ();
my @addrtags;
my %notestags = ();
my %namestags = ();
my $drop =0;

my $xml = XMLin($input_filename, ForceArray=>['userProfile'],ForceArray=>['entry'],
                                 ContentKey => '-content', SuppressEmpty => 1);

RECORD:
foreach my $user (@{$xml->{user}}) {
   last RECORD if ($debug && $i>1);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print Dumper($user);
   foreach my $kee (keys %$user){
      $tags{$kee}++;
   }
   for $i (1..3) {
      if (exists $user->{address}->{$i}->{entry}) {
         foreach my $kee (keys %{$user->{address}->{$i}->{entry}} ){
            $addrtags[$i]{$kee}++;
         }
      }
   } 
   foreach my $kee (keys %{$user->{extendedInfo}->{entry}} ){
#            print Dumper($user) if $kee eq 'name';
#            $drop=1 if $kee eq 'name';
      $notestags{$kee}++;
   }
   foreach my $kee (keys %{$user->{name}} ) {
      $namestags{$kee}++;
   }
}

print << "END_REPORT";

$i records read.

END_REPORT

say 'Main keys:';
foreach my $kee (sort keys %tags) {
   say "$kee:  $tags{$kee}";
}
print "\n";

for $i (1..3) {
   say "Address $i keys:";
   foreach my $kee (sort keys %{$addrtags[$i]}) {
      say "$kee:  $addrtags[$i]{$kee}";
   }
   print "\n";
}

say 'Name keys:';
foreach my $kee (sort keys %namestags) {
   say "$kee:  $namestags{$kee}";
}
print "\n";

say 'Notes keys:';
foreach my $kee (sort keys %notestags) {
   say "$kee:  $notestags{$kee}";
}
print "\n";

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
