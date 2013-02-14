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
use C4::Items;
use MARC::Record;
use MARC::Field;

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

my $input_filename = $NULL_STRING;
my $branchcode     = $NULL_STRING;
my $shortbranch    = $NULL_STRING;
my $marc           = $NULL_STRING;
my $report_filename = $NULL_STRING;
my $auth_match     = $NULL_STRING;
my $title_match    = $NULL_STRING;
my $bar_field      = $NULL_STRING;
my $call_field     = $NULL_STRING;
my $price_field    = $NULL_STRING;
my $notes_field    = $NULL_STRING;
my $lost_field     = $NULL_STRING;
my $damaged_field  = $NULL_STRING;
my $missing_field  = $NULL_STRING;

GetOptions(
    'in=s'     => \$input_filename,
    'branch=s' => \$branchcode,
    'shortbranch=s' => \$shortbranch,
    'marc=s'   => \$marc,
    'report=s' => \$report_filename,
    'auth=s'   => \$auth_match,
    'title=s'  => \$title_match,
    'bar=s'    => \$bar_field,
    'call=s'   => \$call_field,
    'price=s'  => \$price_field,
    'notes=s'  => \$notes_field,
    'lost=s'   => \$lost_field,
    'damage=s' => \$damaged_field,
    'miss=s'   => \$missing_field,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

for my $var ($input_filename,$branchcode,$shortbranch,$marc,$auth_match,$title_match,$report_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $dbh=C4::Context->dbh();
my $bib_sth=$dbh->prepare("SELECT biblionumber,biblioitemnumber,itemtype FROM biblio 
                           JOIN biblioitems USING (biblionumber)
                           WHERE (title LIKE ? OR LOWER(title) = ?)
                           AND (author LIKE ? OR publishercode LIKE ?)");
my $item_sth=$dbh->prepare("SELECT itemnumber FROM items WHERE biblionumber=? AND homebranch=? AND barcode LIKE 'TMP-%'");
my $matches    = 0;
my $no_matches = 0;
my $items_created = 0;
open my $input_file,'<',$input_filename;
open my $output_file,'>:utf8',$marc;
open my $report_file,'>:utf8',$report_filename;
my $csv=Text::CSV_XS->new({ binary => 1 });
$csv->column_names($csv->getline($input_file));
LINE:
while (my $line=$csv->getline_hr($input_file)) {
   last LINE if ($debug and $matches >0); 
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $title = $line->{$title_match};
   $title =~ s/^\*//;
   $title =~ s/copy \d//i;
   $title =~ s/, \w+ ed.*$//i; 
   $title =~ s/\(.*$//;
   $title =~ s/\[.*$//;
   $title =~ s/\s+$//;
   $title =~ s/\.+$//;
   $title =~ s/, The$//i;
   $title =~ s/, The: /: /i;
   $title =~ s/, A$//i;
   $title =~ s/, A: /: /i;
   $title =~ s/\/ /: /g;
   $title =~ s/: / : /g;
   $title =~ s/  / /g;
   my $title_clean = lc $title;
   $title =~ s/&/%/g;
   $title =~ s/ and / % /g;
   $title = '%'.$title.'%';
   my $author = $line->{$auth_match};
   $author =~ s/ and.*$//;
   $author =~ s/\(.*$//;
   $author =~ s/\s+$//;
   $author =~ s/,.*$//;
   $author =~ s/\.+$//;
   $author .= '%';
   $bib_sth->execute($title,$title_clean,$author,$author);
   my $biblio = $bib_sth->fetchrow_hashref();
   if (!$biblio->{biblionumber}) {   #TODO:  Make a MARC here and output it.
      my $rec = MARC::Record->new();
      $rec->leader( '     nam a22        4500');
      my $fld = MARC::Field->new ('100',' ',' ','a' => $line->{$auth_match});
      $rec->insert_grouped_field($fld);
      $fld = MARC::Field->new ('245',' ',' ','a' => $line->{$title_match});
      $rec->insert_grouped_field($fld);
      $fld = MARC::Field->new ('952',' ',' ','a' => $branchcode);
      $fld->update( 'b' => $branchcode );
      $fld->update( 'y' => 'CIRC' );
      $fld->update( 'p' => $shortbranch.'-'.$line->{$bar_field} );
      $fld->update( 'o' => $line->{$call_field} );
      if ($price_field ne $NULL_STRING) {
         if ($line->{$price_field} ne $NULL_STRING){
            $fld->update( 'g' => $line->{$price_field} );
         }
      }

      if ($notes_field ne $NULL_STRING) {
         if ($line->{$notes_field} ne $NULL_STRING) {
            $fld->update( 'x' => $line->{$notes_field} );
         }
      }

      if ($lost_field ne $NULL_STRING) {
         if ($line->{$lost_field} ne $NULL_STRING) {
            $fld->update({ '1' => 1 } );
         }
      }

      if ($missing_field ne $NULL_STRING) {
         if ($line->{$missing_field}) {
            $fld->update({ '1' => 4 } );
         }
      }

      if ($damaged_field ne $NULL_STRING) {
         if ($line->{$damaged_field}) {
            $fld->update({ '4'  => 1 } );
         }
      }
      $rec->insert_grouped_field($fld);
      print {$output_file} $rec->as_usmarc();
      print {$report_file} "$line->{$title_match}\t$line->{$auth_match}\t$line->{$call_field}\n";
      $no_matches++;
      next LINE;
   }
   my $biblionumber = $biblio->{biblionumber};
   $item_sth->execute($biblio->{biblionumber},$branchcode);
   my $item = $item_sth->fetchrow_hashref();
   my $itemnumber = $item->{itemnumber};
   if (!$item->{itemnumber}) {
      $doo_eet and (undef,undef,$itemnumber) = AddItem({ barcode       => 'TMP'.$i,
                                                         itype         => 'CIRC',
                                                         homebranch    => $branchcode,
                                                         holdingbranch => $branchcode,
                                                       },$biblionumber);
      $items_created++;
   }
   
   $doo_eet and ModItem({ barcode        => $shortbranch.'-'.$line->{$bar_field},
                          itype          => 'CIRC',
                          itemcallnumber => $line->{$call_field} },undef,$itemnumber);
   if ($price_field ne $NULL_STRING) {
      if ($line->{$price_field} ne $NULL_STRING){ 
         $doo_eet and ModItem ({ price            => $line->{$price_field},
                                 replacementprice => $line->{$price_field} },undef,$itemnumber);
      }
   }

   if ($notes_field ne $NULL_STRING) {
      if ($line->{$notes_field} ne $NULL_STRING) {
         $doo_eet and ModItem ({ paidfor => $line->{$notes_field} },undef,$itemnumber);
      }
   }

   if ($lost_field ne $NULL_STRING) {
      if ($line->{$lost_field} ne $NULL_STRING) {
         $doo_eet and ModItem ({ itemlost => 1 },undef,$itemnumber);
      }
   }

   if ($missing_field ne $NULL_STRING) {
      if ($line->{$missing_field}) {
         $doo_eet and ModItem ({ itemlost => 4 },undef,$itemnumber); 
      }
   }

   if ($damaged_field ne $NULL_STRING) {
      if ($line->{$damaged_field}) { 
         $doo_eet and ModItem ({ damaged => 1 },undef,$itemnumber); 
      }
   }
   $debug and print "Biblio: $biblionumber  Item $itemnumber\n";
   $debug and print Dumper($line);
   $matches++;
}
close $input_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not loaded due to problems.
$matches matches found.
$items_created items added to matched bibs.
$no_matches records didn't find a bib match.
END_REPORT

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
