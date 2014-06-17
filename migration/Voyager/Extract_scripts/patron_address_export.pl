#!/m1/shared/bin/perl

use strict;
use warnings;
use DBI;
$|=1;

$ENV{ORACLE_SID} = "VGER";
$ENV{ORACLE_HOME} = "/oracle/app/oracle/product/11.2.0.3/db_1";
our $db_name = "gmcdb";
our $username = "gmcdb";
our $password = "Qgmcdb";
our $sqllogin = 'gmcdb/Qgmcdb@VGER';

my $dbh = DBI->connect('dbi:Oracle:', $sqllogin) || die "Could not connect: $DBI::errstr";
my $query = "SELECT patron_address.patron_id,
                    patron_address.address_type,
                    patron_address.address_line1,patron_address.address_line2,
                    patron_address.address_line3,patron_address.address_line4,
                    patron_address.address_line5,patron_address.city,
                    patron_address.state_province,patron_address.zip_postal,
                    patron_address.country
               FROM patron_address";

my $sth=$dbh->prepare($query) || die $dbh->errstr;
$sth->execute() || die $dbh->errstr;

my $i=0;
open my $out,">","patron_address_data.csv" || die "Can't open the output!";

while (my @line = $sth->fetchrow_array()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   for my $k (0..scalar(@line)-1){
      if ($line[$k]){
         $line[$k] =~ s/"/'/g;
         if ($line[$k] =~ /,/){
            print $out '"'.$line[$k].'"';
         }
         else{
            print $out $line[$k];
         }
      }
      print $out ',';
   }
   print $out "\n";
}   

close $out;
print "\n\n$i patrons exported\n";