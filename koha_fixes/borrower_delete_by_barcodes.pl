# Written by: Joy Nelson
#
# EXPECTS:
#  -csv of borrowernumber cardnumber
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of borrowers deleted

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use MARC::Record;
use MARC::Field;
use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Serials;
use C4::Members;
use MARC::Record;
use MARC::Field;

$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;
my $in_file ="";

GetOptions(
    'debug'    => \$debug,
    'update'   => \$doo_eet,
    'file:s'   => \$in_file,
);


if ($in_file eq q{}){
   print "Something's missing.\n";
   exit;
}

my $deleted = 0;
my $dbh = C4::Context->dbh();
my $csv = Text::CSV_XS->new();
open my $infl,"<",$in_file;
my $patron_sth = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE cardnumber=?");

#spin through your CSV and move member to deleted.
my @data;
my $line;

while ($line=$csv->getline($infl)){
  @data = @$line;

  $patron_sth->execute($data[0]);
  my $patron_fetch=$patron_sth->fetchrow_hashref();
  my $patron_num=$patron_fetch->{'borrowernumber'};

  if ($patron_num) {
   print "deleting patron borrowernumber: $patron_num with cardnumber $data[0]\n";
    if ($doo_eet){
      my $result=MoveMemberToDeleted($patron_num);
      $deleted++;
      if ($result == 1) {
       DelMember($patron_num);
      }
    }
  }
}

print "\n$deleted borrower records deleted and moved to deleted_borrower table.\n";




