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

my $tagfield="";
my $tagsubfield="";
my $normalize="";
my $best="longest";

GetOptions(
    'tag=s'         => \$tagfield,
    'sub=s'         => \$tagsubfield,
    'normalize=s'   => \$normalize,
    'best=s'        => \$best,
    'debug'         => \$debug,
    'update'        => \$doo_eet,
);

if (($tagfield eq q{}) || ($tagfield > 10 && $tagsubfield eq q{})){
   print "Something's missing.\n";
   exit;
}

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
my $sth=$dbh->prepare("SELECT biblionumber FROM biblioitems");
my $marc_sth=$dbh->prepare("SELECT marc FROM biblioitems WHERE biblionumber=?");
my $entry_sth=$dbh->prepare("SELECT author,title FROM biblio where biblionumber=?");
$sth->execute();

RECORD:
while (my $row=$sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   $marc_sth->execute($row->{biblionumber});
   my $rec = $marc_sth->fetchrow_hashref();
   my $marc = MARC::Record->new_from_usmarc($rec->{marc});
   my $field;
   my $data;
   if ($tagfield < 10){
      my $tagg = $marc->field($tagfield);
      if ($tagg){
         $field = $tagg->data();
      }
   }
   else{
      $field = $marc->subfield($tagfield,$tagsubfield);
   }
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

   $insert_sth->execute($row->{biblionumber},$data);
   $inserted++;
} 

print "\n$i records read from database.\n$inserted lines inserted to dedupe table.\n";
print "$field_not_present records not considered due to missing or invalid field.\n\n";

my $dupes_found=0;
my $dupe_sth=$dbh->prepare("SELECT GROUP_CONCAT(biblionumber ORDER BY biblionumber DESC SEPARATOR '~') AS biblionumbers, normal_data FROM temp_dedupe GROUP BY normal_data HAVING COUNT(normal_data)>1 ORDER BY normal_data");
$dupe_sth->execute();
MATCH:
while (my $row=$dupe_sth->fetchrow_hashref()){
   last MATCH if ($debug and $dupes_found>0);
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
      if ($tagfield < 10){
         my $tagg = $marc->field($tagfield);
         if ($tagg){
            $field = $tagg->data();
         }
      }
      else{
         $field = $marc->subfield($tagfield,$tagsubfield);
      }
      $entry_sth->execute($thisone);
      my $thisentry=$entry_sth->fetchrow_hashref();
      my $title=$thisentry->{title} || '';
      my $author=$thisentry->{author} || '';
      my $reclen = substr($marc->leader(),0,5);
    
      if ($best eq 'longest'){
         if ($reclen >= $bestval){
            $bestval=$reclen;
            $best_rec=$thisone;
         }
      }

      print "$thisone (Len: $reclen): $field~$title~$author\n";
   }
   print "USING RECORD $best_rec\n";
   my $reserves_modified = 0;
   my ($rescount,undef) = &GetReserves($thisone);
   if ($rescount > 0) {
      $reserves_modified = 1;
      print "Holds updated!\n";
   }
 
   if ($doo_eet){
      foreach my $thisone (@biblios){
         next if ($thisone == $best_rec);
      
         my @errors;

         # Move items
         my @notmoveditems;
         my $itemnumbers = get_itemnumbers_of($thisone);
         foreach my $itloop ($itemnumbers->{$thisone}) {
            foreach my $itemnumber (@$itloop) {
               my $res = MoveItemFromBiblio($itemnumber, $thisone, $best_rec);
               if (not defined $res) {
                  push @notmoveditems, $itemnumber;
               }
            }
         }
         # If some items could not be moved :
         if (scalar(@notmoveditems) > 0) {
             my $itemlist = join(' ',@notmoveditems);
             push @errors, "The following items could not be moved from the old record to the new one: $itemlist";
         }
 
         # Move reserves
         $sth=$dbh->prepare("UPDATE reserves SET biblionumber = ? where biblionumber =?");
         $sth->execute($best_rec, $thisone);

         $sth=$dbh->prepare("UPDATE old_reserves SET biblionumber = ? where biblionumber =?");
         $sth->execute($best_rec, $thisone);

         # Move serials
         my $subcount = CountSubscriptionFromBiblionumber($thisone);
         if ($subcount > 0) {
            $sth = $dbh->prepare("UPDATE subscription SET biblionumber = ? WHERE biblionumber = ?");
            $sth->execute($best_rec, $thisone);

            $sth = $dbh->prepare("UPDATE subscriptionhistory SET biblionumber = ? WHERE biblionumber = ?");
            $sth->execute($best_rec, $thisone);
         }
         $sth = $dbh->prepare("UPDATE serial SET biblionumber = ? WHERE biblionumber = ?");
         $sth->execute($best_rec, $thisone);

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
if ($reserves_modified) {
   print "You'll need to run the holds-queue priority fixer, fix_holds_priority.pl with -a! \n";
}
#$dbh->do("DROP TABLE IF EXISTS temp_dedupe;");
