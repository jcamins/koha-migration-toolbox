#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use MARC::Charset;
use MARC::Field;
use MARC::Record;
use MARC::File::XML;
use Text::CSV;
use C4::Context;
use C4::Items;
$|=1;
my $debug=0;
my $doo_eet=0;

my $infile_name = "";

GetOptions(
    'in=s'            => \$infile_name,
    'debug'           => \$debug,
    'update'          => \$doo_eet,
);

if (($infile_name eq '') ){
  print "Something's missing.\n";
  exit;
}

my $csv = Text::CSV->new({ binary => 1 });
open my $in,"<$infile_name";
my $i=0;
my $j=0;
my $problem=0;
my $iggy = MARC::Charset::ignore_errors(1);
my $setting = MARC::Charset::assume_encoding('utf8');
my $dbh = C4::Context->dbh();
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE barcode=?");
my $thisborrowerbar = "";
my $thisborrower;
RECORD:
while (my $line = $csv->getline($in)) {
   my @data = @$line;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   
   next RECORD if (($data[0] eq q{}) || ($data[1] eq q{}));

   my $thisitembar = $data[0];
   $item_sth->execute($thisitembar);
   my $hash=$item_sth->fetchrow_hashref();
   my $thisitem = $hash->{'itemnumber'};
  
   if ($thisitem){
      my $record = MARC::Record->new_from_usmarc($data[1]);
      my $acqdata = $record->subfield('852','x');
      next RECORD if (!$acqdata);

      $j++;
      $debug and print "I:$thisitembar S:$acqdata\n";
      if ($doo_eet){
         C4::Items::ModItem({booksellerid => $acqdata },undef,$thisitem);
      }
   }
   else{
      print "\nProblem record:\n";
      print "I:$thisitembar ($thisitem) S:$data[1]\n";
      $problem++;
   }
   next;
}

close $in;

print "\n\n$i lines read.\n$j items modified.\n$problem problem lines.\n";
exit;
