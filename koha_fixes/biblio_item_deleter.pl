# Written by: Joy Nelson
#
# CREATES:
#   -nothing
#
# REPORTS:
#   -count of biblios deleted

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
my $csv = Text::CSV->new();
open my $infl,"<",$in_file;
my $item_sth = $dbh->prepare("SELECT itemnumber FROM items WHERE biblionumber=?");

#spin through your CSV, and find itemnumber, DelItem and
# DelBiblio on the biblionumber from csv.
my @data;
my $line;

while ($line=$csv->getline($infl)){
  @data = @$line;
  $item_sth->execute($data[0]);
  my $db_item_fetch=$item_sth->fetchrow_hashref();
  my $itemnum=$db_item_fetch->{'itemnumber'};
  if (!$itemnum) {
   print "\n items not found for $data[0]\n";
   next;
  }
  if ($doo_eet){
     C4::Items::DelItem($dbh, $data[0], $itemnum);
     $i++;
     C4::Biblio::DelBiblio($data[0]);
     $deleted++;
  }
}

print "\n$i items deleted\n$deleted records deleted.\n";




