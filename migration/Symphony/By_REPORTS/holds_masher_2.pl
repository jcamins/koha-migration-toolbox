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
use Encode;
use Getopt::Long;
use Text::CSV_XS;
use C4::Context;
use MARC::Record;
use MARC::Field;
use Business::ISBN;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $branch_map_name = "";
my %branch_map;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'branch_map=s'  => \$branch_map_name,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

if ($branch_map_name){
   my $csv = Text::CSV_XS->new();
   open my $mapfile,"<$branch_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $i=0;
my $written=0;

my %thisrow;
my $nextline=0;
my @hold_fields= qw{ borrowerbar bibliobar reservedate constrainttype branchcode expirationdate };

my $dbh=C4::Context->dbh();

print "Loading bib match points:\n";
my $sth=$dbh->prepare("select biblionumber from biblioitems");
$sth->execute();
my $rec_sth=$dbh->prepare("select marc from biblioitems where biblionumber = ?");
my $k=0;
my %a_map;
my %i_map;
my %o_map;
BIB:
while (my $rec=$sth->fetchrow_hashref()){
#   last BIB if ($debug and $k>20);
   $k++;
   print "." unless ($k % 10);
   print "\r$k" unless ($k % 100);
   $rec_sth->execute($rec->{biblionumber});
   my $rawrec = $rec_sth->fetchrow_hashref();
   my $marc = MARC::Record->new_from_usmarc($rawrec->{marc});
#   $debug and print $marc->as_formatted();
   my $field = $marc->subfield('998','a');
   if ($field){
#      $debug and print $field;
      $a_map{$field} = $rec->{biblionumber};
   }
   $field = $marc->field('001');
#   $debug and print Dumper($field);
   if ($field){
      my $data = $field->data();
#      $debug and print "$data\n";
      $data =~ s/^oc[mn]//;
      $o_map{$data} = $rec->{biblionumber};
   }
   my @fields = $marc->field('020');
   foreach $field (@fields){
#      $debug and print Dumper($field);
      my $data = $field->subfield('a');
      if ($data){
         $data =~ m/(.+?)[( ]/;
         my $data_2 = uc $1 || $data;
         my $isbn = Business::ISBN->new($data_2);
#         $debug and print "$data_2\n";
#         $debug and print Dumper($isbn);
         if ((exists $isbn->{valid}) && ($isbn->{valid} == 1)){
            my $tang1 = $isbn->as_isbn10;
            my $tang2 = $isbn->as_isbn13;
            if ($tang1 && $tang2){
               $tang1->fix_checksum;
               my $rock1 = $tang1->{isbn};
               $tang2->fix_checksum;
               my $rock2 = $tang2->{isbn};
#               $debug and print Dumper($isbn);
#               $debug and print Dumper($tang1);
#               $debug and print Dumper($tang2);
#               $debug and print "\n$rock1   $rock2 \n"; 
               $i_map{$rock1} = $rec->{biblionumber};
               $i_map{$rock2} = $rec->{biblionumber};
            }
         }
      }
   }
}
#$debug and print Dumper(%a_map);
#$debug and print Dumper(%i_map);
#$debug and print Dumper(%o_map);
#$debug and exit;
print "\n$k bib records read.\n\n";

open my $infl,"<",$infile_name || die ('problem opening $infile_name');
open my $outfl,">",$outfile_name || die ('problem opening $outfile_name');
for my $j (0..scalar(@hold_fields)-1){
   print $outfl $hold_fields[$j].',';
}
print $outfl "\n";

my $item_sth=$dbh->prepare("SELECT barcode FROM items where biblionumber = ? LIMIT 1");
LINE:
while (my $line = readline($infl)){
   #last LINE if ($debug && $written >50);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   chomp $line;
   $line =~ s///g;
   next LINE if $line eq q{};
   next LINE if $line =~ /^\s+$/;

   if ($line =~ m/^[a-z][0-9]/){
      $line =~ m/^[a-z]([0-9]+)\s+/;
      my $linedata = $1;
      if ($thisrow{bibliobar}){
         $thisrow{constrainttype} = 'a';
         for my $p (0..scalar(@hold_fields)-1){
            if ($thisrow{$hold_fields[$p]}){
               $thisrow{$hold_fields[$p]} =~ s/\"/'/g;
               if ($thisrow{$hold_fields[$p]} =~ /,/){
                  print $outfl '"'.$thisrow{$hold_fields[$p]}.'"';
               }
               else{
                  print $outfl $thisrow{$hold_fields[$p]};
               }
           }
            print $outfl ",";
         }
         print $outfl "\n";
         $written++;

       # write what we got, clear thisrow;
         %thisrow=();
      }
      my $biblionumber = q{};
      my $prefix;
      if ($line =~ m/^a/){
         $biblionumber=$a_map{$linedata} || q{}; 
         $prefix = 'a';
      }
      if ($line =~ m/^o/){
         $biblionumber=$o_map{$linedata} || q{};; 
         $prefix = 'o';
      }
      if ($line =~ m/^i/){
         $biblionumber=$i_map{$linedata} || q{};; 
         $prefix = 'i';
      }
      $debug and print "\nFlex Key: $prefix  $linedata    Biblio: $biblionumber\n";
      if ($biblionumber ne q{}){
         $item_sth->execute($biblionumber);
         my $itmrec = $item_sth->fetchrow_hashref();
         $thisrow{bibliobar} = $itmrec->{barcode};
      }
   }
   if ($line =~ m/user id/){
      if ($thisrow{bibliobar} && $thisrow{borrowerbar}){
         $thisrow{constrainttype} = 'a';
         for my $p (0..scalar(@hold_fields)-1){
            if ($thisrow{$hold_fields[$p]}){
               $thisrow{$hold_fields[$p]} =~ s/\"/'/g;
               if ($thisrow{$hold_fields[$p]} =~ /,/){
                  print $outfl '"'.$thisrow{$hold_fields[$p]}.'"';
               }
               else{
                  print $outfl $thisrow{$hold_fields[$p]};
               }
           }
            print $outfl ",";
         }
         print $outfl "\n";
         $written++;

         $thisrow{borrowerbar} = undef;
         $thisrow{reservedate} = undef;
         $thisrow{expirationdate} = undef;
         $thisrow{branchcode} = undef;
         $thisrow{constrainttype} = undef;
      }
      $line =~ m/user id:(\d+)/;
      $thisrow{borrowerbar} = $1;
   }
   if ($line =~ m/priority:/){
      if ($line =~ m/placed:(\d+)\/(\d+)\/(\d+)\s+expires:(\d+)\/(\d+)\/(\d+)/){
         $thisrow{reservedate} = sprintf "%4d-%02d-%02d",$3,$1,$2;
         $thisrow{expirationdate} = sprintf "%4d-%02d-%02d",$6,$4,$5;
      } 
      else{
         $line=~ m/placed:(\d+)\/(\d+)\/(\d+)/;
         $thisrow{reservedate} = sprintf "%4d-%02d-%02d",$3,$1,$2;
         $thisrow{expirationdate} = "2011-12-31";
      }
   }
   if ($line =~ m/hold library:/){
      $line=~ m/hold library:(\w+)/;
      $thisrow{branchcode} = $1;
      if ($branch_map{$thisrow{branchcode}}){
         $thisrow{branchcode} = $branch_map{$thisrow{branchcode}};
      }
   }
}

close $infl;
close $outfl;

print "\n\n$i lines read.\n$written holds written.\n";
