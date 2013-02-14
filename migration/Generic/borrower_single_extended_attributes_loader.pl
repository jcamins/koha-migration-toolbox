#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
# -Joy Nelson
#   edited to load only single occurrence attributename
#---------------------------------
#
# EXPECTS:
#   -CSV of barcodes and borrower attribute strings
#
# DOES:
#   -inserts borrower attributes, if --update is set
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -what would be changed, if --debug is set
#   -count of lines read
#   -count of attribute strings written

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use C4::Context;
use C4::Members;
use C4::Members::Attributes;
use C4::Members::Attributes qw /extended_attributes_code_value_arrayref/;
use C4::Members::AttributeTypes;


local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename = "";

GetOptions(
    'in=s'     => \$input_filename,
    'debug'   => \$debug,
    'update'   => \$doo_eet,

);

for my $var ($input_filename) {
   croak ('You are missing something') if $var eq $NULL_STRING;
}

my $extended = C4::Context->preference('ExtendedPatronAttributes');
if (!$extended) {
   croak ('This instance of Koha is not running ExtendedPatronAttributes.');
}

my $csv = Text::CSV_XS->new({binary => 1});
my $dbh=C4::Context->dbh();
my $attr_sth=$dbh->prepare("SELECT borrowernumber from borrower_attributes where borrowernumber=? and code=?");
open my $input_file,'<',$input_filename;

LINE:
while (my $line=$csv->getline($input_file)) {
   last LINE if ($debug and $i>9);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data = @$line;

   my $member = GetMember( 'cardnumber' => $data[0] );
   if (!$member) {
      print "Borrower $data[0] not found.\n";
      $problem++;
      next LINE;
   }
   
   my $borrowernumber = $member->{borrowernumber};
   my $patron_attributes = extended_attributes_code_value_arrayref($data[1]);
   $debug and print "Borr: $data[0] ($borrowernumber)\n".Dumper($patron_attributes);

   foreach my $element (split /,/ , $data[1]) {
      my ($attribute_name, $attr_value) = split(/:/,$element);

      $attr_sth->execute($borrowernumber,$attribute_name);
      my $attr=$attr_sth->fetchrow_hashref();
      if (!$attr) {
         if ($doo_eet){
             my $single_attr = extended_attributes_code_value_arrayref($element);
             C4::Members::Attributes::SetBorrowerAttributes($borrowernumber, $single_attr);
         }
         $written++;
      }
   }
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
END_REPORT

exit;
