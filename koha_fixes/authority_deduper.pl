#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
# Comments:
#
#  If you are deduping LARGE numbers of bibliographic records you may run into problems with line 129 
#  group_concat may truncate results.  If so, then you need to login in to mysql as root and 
#  SET GLOBAL group_concat_max_len=5000;  to reset the max length allowed. -jn 6/27/2012
#
#---------------------------------

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use C4::Context;
use C4::Biblio;
use C4::Items;
use C4::Reserves;
use C4::Serials;
use MARC::Record;
use MARC::Field;

$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $tagfield="1..";
my $normalize="case";
my $best="longest";

GetOptions(
    'tag=s'         => \$tagfield,
    'normalize=s'   => \$normalize,
    'best=s'        => \$best,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

my $field_not_present=0;
my $inserted=0;

my $dbh=C4::Context->dbh();
print "Creating temporary table, populating with normalized data.\n";
$dbh->do("DROP TABLE IF EXISTS temp_dedupe;");
$dbh->do("CREATE TABLE temp_dedupe
          (entry_id int NOT NULL AUTO_INCREMENT PRIMARY KEY,
           biblionumber int(11) NOT NULL, 
           normal_data varchar(255) NOT NULL,
           KEY normal_data (normal_data))
          ENGINE=InnoDB CHARSET=utf8;");
my $insert_sth=$dbh->prepare("INSERT INTO temp_dedupe (biblionumber,normal_data) VALUES (?,?)");
my $sth=$dbh->prepare("SELECT authid FROM auth_header");
my $marc_sth=$dbh->prepare("SELECT marc FROM auth_header WHERE authid=?");
$sth->execute();

RECORD:
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $marc_sth->execute($row->{authid});
   my $rec = $marc_sth->fetchrow_hashref();
   my $marc = MARC::Record->new_from_usmarc($rec->{marc});
   my $field;
   my $data;
   my $field_whole = $marc->field($tagfield);
   if (!$field_whole) {
      $field_not_present++;
      next RECORD;
   }
   $field=$field_whole->as_string();
   if (!$field){
      $field_not_present++;
      next RECORD;
   }
   
   $data=$field;
   
   if ($normalize =~ m/isbn/){
      $field =~ m/(.+?)[( ]/;
      $data = uc $1;
      if ($data eq q{}){
         $data = uc($field);
      }
      $data =~ s/\-//g;
      if (length($data) == 10){
         $data='978'.$data;
      }
      if (length($data) != 13){
         $field_not_present++;
         next RECORD;
      }
   }

   if ($normalize =~ m/case/){
      $data = uc($data);
   }

   $data =~ s/  / /g;
   $data =~ s/(\s+)$//;

   $insert_sth->execute($row->{authid},$data);
   $inserted++;
} 

print "\n$i records read from database.\n$inserted lines inserted to dedupe table.\n";
print "$field_not_present records not considered due to missing or invalid field.\n\n";

my $dupes_found=0;
my $reserves_modified=0;
my $dupe_sth=$dbh->prepare("SELECT GROUP_CONCAT(biblionumber ORDER BY biblionumber DESC SEPARATOR '~') AS biblionumbers, normal_data FROM temp_dedupe GROUP BY normal_data HAVING COUNT(normal_data)>1 ORDER BY normal_data");
$dupe_sth->execute();
MATCH:
while (my $row=$dupe_sth->fetchrow_hashref()){
   last MATCH if ($debug and $dupes_found>1000000);
   print "-------------------------------------------------------\n";
   $dupes_found++;
   my @biblios = split(/~/,$row->{biblionumbers});
   my $bestval=0;
   my $best_rec='';
   foreach my $thisone (@biblios){
      $marc_sth->execute($thisone);
      my $rec = $marc_sth->fetchrow_hashref();
      my $marc = MARC::Record->new_from_usmarc($rec->{marc});
      my $field;
      my $field_whole = $marc->field($tagfield);
      $field = $field_whole->as_string();
      my $reclen = substr($marc->leader(),0,5);
    
      if ($best eq 'longest'){
         if ($reclen >= $bestval){
            $bestval=$reclen;
            $best_rec=$thisone;
         }
      }

      print "$thisone (Len: $reclen): $field\n";
   }
   print "USING RECORD $best_rec\n";
 
   if ($doo_eet){
      foreach my $thisone (@biblios){
         next if ($thisone == $best_rec);
      
         my @errors;

         # Delete the old record, but only if there haven't been any errors.
         if (scalar(@errors) == 0) {
            my $error = DelBiblio($thisone);
            push @errors, $error if ($error);
         }

         # Output errors, if any.
         if (scalar(@errors) >0) {
            print "ERROR!\n";
            print join ('\n',@errors);
         }
      }
   }
}
print "$dupes_found duplicates found.\n";
#$dbh->do("DROP TABLE IF EXISTS temp_dedupe;");
