#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -formatted CSV files with the following column heads, in THIS order:
#      Accession_number,     Record_Type,          Location,            Call number,       Call number-pamphlet, 
#      Bimonthly volume,     Author,               Responsibility note, Book Title,        Article Title, 
#      Title - All,          Edition,              Series,              Year - All,        Publisher,
#      Year of Publication,  Journal,              Journal Volume,      Journal date-year, Pagination,
#      Copies,               Volumes,              Price,               ISBN,              ISSN,
#      Main Heading,         Subject,              New subject,         Abstract,          Notes,
#      Added by,             Item Status,          Date cataloged,      Date modified,     Order date,
#      Book status,          Entry number,         City - State,        Title main entry,  Title sort,
#      Volume info,          Place of Publication, Main entry Sort,     Local note,        Full text URL,
#      Full text URLcaption, Related URL,          Related URL caption, Circulating copy,  ISBN-13
#      Linkcheck
#
# DOES:
#   -nothing
#
# CREATES:
#   -MARC file
#
# REPORTS:
#   -count of records read
#   -count of MARCs built and output

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use Text::CSV_XS;
use MARC::Record;
use MARC::Field;
$|=1;
my $debug=0;
my $doo_eet=0;
my $i=0;

my $infile_name   = q{};
my $outfile_name  = q{};


GetOptions(
    'in:s'     => \$infile_name,
    'out:s'    => \$outfile_name,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq q{}) || ($outfile_name eq q{})){
   print "You're missing something.\n";
   exit;
}

my $written=0;
my %leaders=(
               'Article'             => '     naa a22        4500',
               'CD-ROM'              => '     nmm a22        4500',
               'DVD'                 => '     ngm a22        4500',
               'Dissertation'        => '     nam a22        4500',
               'Electronic resource' => '     nmm a22        4500',
               'Monograph'           => '     nam a22        4500',
               'Monograph|DVD'       => '     nam a22        4500',
               'Pamphlet'            => '     nam a22        4500',
               'Sound recording'     => '     nim a22        4500',
               'Video recording'     => '     ngm a22        4500',
               'Sound Recording'     => '     nim a22        4500',
               'Video Recording'     => '     ngm a22        4500',
            );
my %locations=(
               'Atlanta'       => 'ATLANTA',
               'Cleveland'     => 'CLEVELAND',
               'DC'            => 'DC',
               'Internet'      => 'ONLINE',
               'New York'      => 'NEWYORK',
               'San Francisco' => 'SANFRAN',
              );
my %itemtypes=(
               'Article'             => 'ART',
               'CD-ROM'              => 'CD',
               'DVD'                 => 'DVD',
               'Dissertation'        => 'DIS',
               'Electronic resource' => 'COM',
               'Monograph'           => 'REF',
               'Monograph|DVD'       => 'REF',
               'Pamphlet'            => 'PAM',
               'Sound recording'     => 'SND',
               'Video recording'     => 'VID',
               'Sound Recording'     => 'SND',
               'Video Recording'     => 'VID',
            );

my %barcode_counts;
my $csv = Text::CSV_XS->new({binary => 1, sep_char => "\t"});
open my $in,"<:encoding(cp1252)",$infile_name;
open my $out,">:utf8",$outfile_name;
#my $line = readline($in);
#chomp $line;
#$line =~ s///g;
#$debug and print "$line\n";
#my @columns = split (/\t/,$line);
my $line = $csv->getline($in);
my @columns = @$line;

RECORD:
#while (my $line=readline($in)){
while (my $line=$csv->getline($in)){
   last RECORD if ($debug and $written>20);
   $i++;
   print '.' unless ($i % 10);
   print "\r$i" unless ($i % 100);
#   $line =~ s///g;
#   my @data=split(/\t/,$line);
   my @data = @$line;
   next RECORD if (scalar (@data)==1);
   if (scalar(@data) < 51){
      my $err = "problem record $i\nOld size: ".scalar(@data).'   ';
      $i++;
      my $line2 = readline($in);
      $line .= ' '.$line2;
      @data=split(/\t/,$line);
      $err .= "New size: ".scalar(@data)."\n";
      $debug and print $err if (scalar(@data) != 51);
      next RECORD if (scalar(@data) != 51);
   }
   my $rec = MARC::Record->new();
   $rec->leader($leaders{$data[1]});

   if ($data[0] ne q{}){
      my $fld = MARC::Field->new( '945',' ',' ','a' => $data[0] );
      $rec->insert_grouped_field($fld);
   }

   if ($data[3] ne q{}){
      my $fld = MARC::Field->new( '099',' ',' ','a' => $data[3] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[4] ne q{}){
      my $fld = MARC::Field->new( '099',' ',' ','a' => 'Subject file: '.$data[4] );
      $rec->insert_grouped_field($fld);
   }

   if ($data[5] ne q{}){
      my $fld = MARC::Field->new( '901',' ',' ','a' => $data[5] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[6] ne q{}){
      my $first;
      my $rest;
      if ($data[6] !~ m/\|/){
         $first = $data[6];
      }
      else{
         ($first,$rest) = split (/\|/,$data[6],2);
      }
      my $fld = MARC::Field->new( 100,' ',' ','a' => $first );
      $rec->insert_grouped_field($fld);
      if ($rest){
         foreach my $this (split (/\|/,$rest)){
            my $fld2 = MARC::Field->new( 700,' ',' ','a' => $this);
            $rec->insert_grouped_field($fld2);
         }
      }
   }
    
   my $fld245 = MARC::Field->new( 245,' ',' ','9' => "TEMP" ); 
   if ($data[9] ne q{}){
      $fld245->update('a' => $data[9] );
   }
   elsif ($data[10] ne q{}){
      $fld245->update('a' => $data[10] );
   }
   if ($data[7] ne q{}){
      $fld245->update('c' => $data[7] );
   }
   $fld245->delete_subfield(code => '9');
   $rec->insert_grouped_field($fld245);
    
   if ($data[11] ne q{}){
      my $fld = MARC::Field->new( 250,' ',' ','a' => $data[11] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[12] ne q{}){
      my ($title,$number) = split (/;/,$data[12],2);
      my $fld = MARC::Field->new( '830',' ',' ','a' => $title, 'p' => $number );
      $rec->insert_grouped_field($fld);
   }
   
   my $fld260 = MARC::Field->new( 260,' ',' ','8' => 1); 
   my $valid_260=0;

   if ($data[41] ne q{}){
      $fld260->update('a' => $data[41] );
      $valid_260=1;
   }

   if ($data[14] ne q{}){
      $fld260->update('b' => $data[14] );
      $valid_260=1;
   }
   
   my $done_008; 
   if ($data[15] ne q{}){
      $fld260->update('c' => $data[15] );
      $valid_260=1;
      $data[15]=~ m/(\d\d\d\d)/;
      my $year_only = $1;
      if ($year_only) {
         my $fld = MARC::Field->new('008','      s'.$year_only);
         $rec->insert_fields_ordered($fld);
         $done_008 = 1;
      }
   }
   if ($data[18] ne q{}){
      $fld260->update('c' => $data[18] );
      $valid_260=1;
      $data[15]=~ m/(\d\d\d\d)/;
      my $year_only = $1;
      if ($year_only && !$done_008) {
         my $fld = MARC::Field->new('008','      s'.$year_only);
         $rec->insert_fields_ordered($fld);
         $done_008 = 1;
      }
   }
   
   if ($data[1] eq "Article"){
      my $journ = $data[16];
      my $subj = $data[18].', Volume/Issue '.$data[17].', '.$data[19];
      my $fld = MARC::Field->new( 773,' ',' ',
                                    't' => $journ,
                                    'g' => $subj);
      $rec->insert_grouped_field($fld);
      $fld260->update('b' => $journ);
      $fld260->update('g' => 'vol. '.$data[17]); 
      $valid_260=1;
      $data[13]=~ m/(\d\d\d\d)/;
      my $year_only = $1;
      if ($year_only && !$done_008) {
         my $fld = MARC::Field->new('008','      s'.$year_only);
         $rec->insert_fields_ordered($fld);
      }
   }

   if ($valid_260){
      $fld260->delete_subfield(code => '8');
      $rec->insert_grouped_field($fld260);
   }

   if ($data[16] ne q{}){
      my $fld = MARC::Field->new( 440,' ',' ','a' => $data[16]);
      $rec->insert_grouped_field($fld);
   }
   if ($data[19] ne q{}){
      my $fld = MARC::Field->new( 300,' ',' ','a' => $data[19]);
      $rec->insert_grouped_field($fld);
   }

   if ($data[22] ne q{}){
      my $fld = MARC::Field->new( 365,' ',' ','b' => $data[22] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[23] ne q{}){
      my $fld = MARC::Field->new( '020',' ',' ','a' => $data[23] );
      $rec->insert_grouped_field($fld);
   }

   if ($data[24] ne q{}){
      my $fld = MARC::Field->new( '022',' ',' ','b' => $data[24] );
      $rec->insert_grouped_field($fld);
   }

   if ($data[25] ne q{}){
      my $fld = MARC::Field->new( 902,' ',' ','a' => $data[25] );
      #my ($first,$rest) = split(/\-\-/,$data[25],2);
      #my $fld = MARC::Field->new( 653,' ',' ','a' => $first );
      #if ($rest){
      #   foreach my $this (split(/\-\-/,$rest)){
      #      $fld->add_subfields( 'x' => $this);
      #   }
      #}
      $rec->insert_grouped_field($fld);
   }

   if ($data[26] ne q{}){
      foreach my $this (split(/\|/,$data[26])){
         my $fld = MARC::Field->new(650,' ',' ','a' => $this);
         #my ($first,$rest) = split(/\-\-/,$this,2);
         #my $fld = MARC::Field->new( 650,' ',' ','a' => $first );
         #if ($rest){
         #   foreach my $this1 (split(/\-\-/,$rest)){
         #      $fld->add_subfields( 'x' => $this1);
         #   }
         #}
         $rec->insert_grouped_field($fld);
      }
   }

   if ($data[27] ne q{}){
      my ($first,$rest) = split(/\-\-/,$data[27],2);
      my $fld = MARC::Field->new( 690,' ',' ','a' => $data[27] );
      #my $fld = MARC::Field->new( 690,' ',' ','a' => $first );
      #if ($rest){
      #   foreach my $this (split(/\-\-/,$rest)){
      #      $fld->add_subfields( 'x' => $this);
      #   }
      #}
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[28] ne q{}){
      my $fld = MARC::Field->new( 500,' ',' ','a' => $data[28] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[29] ne q{}){
      my $fld = MARC::Field->new( 905,' ',' ','a' => $data[29] );
      $rec->insert_grouped_field($fld);
   }

   if ($data[43] ne q{}){
      my $fld = MARC::Field->new( 530,' ',' ','a' => $data[43] );
      $rec->insert_grouped_field($fld);
   }

   if ($data[30] ne q{}){
      my $fld = MARC::Field->new( 948,' ',' ','a' => $data[30] );
      $rec->insert_grouped_field($fld);
   }

   if ($data[31] ne q{}){
      my $fld = MARC::Field->new( 910,' ',' ','a' => $data[31] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[32] ne q{}){
      my $fld = MARC::Field->new( 946,' ',' ','a' => $data[32] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[33] ne q{}){
      my $fld = MARC::Field->new( 947,' ',' ','a' => $data[33] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[34] ne q{}){
      my $fld = MARC::Field->new( 949,' ',' ','a' => $data[34] );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[44] ne q{}){
      my $note = 'Full text: '.$data[45];
      my $fld = MARC::Field->new( 856,'4','0',
                                   'u' => $data[44],
                                   'z' => $note  );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[46] ne q{}){
      my $note = 'Related information: '.$data[47];
      my $fld = MARC::Field->new( 856,'4','0',
                                   'u' => $data[46],
                                   'z' => $note  );
      $rec->insert_grouped_field($fld);
   }
    
   if ($data[49] ne q{}){
      my $fld = MARC::Field->new( '020',' ',' ','a' => $data[49] );
      $rec->insert_grouped_field($fld);
   }

   foreach my $loc (split(/\|/,$data[2])){
      my $fld = MARC::Field->new( 952,' ',' ',
                                   'a' => $locations{$loc},
                                   'b' => $locations{$loc},
                                   'd' => _process_date($data[32]),
                                   'p' => 'TMP-'.$i.'-'.$locations{$loc});
      if ($loc eq "Internet"){
         $fld->update( 'y' => 'ONLINE','o' => 'Online' );
      }
      else{
         $fld->update ( 'y' => $itemtypes{$data[1]} );
        # if (($locations{$loc} eq "CLEVELAND" || $locations{$loc} eq "ATLANTA") && $data[1] eq 'Monograph') {
        #    $fld->update( 'y' => 'CIRC' );
        # }
      }
      if ($data[3] ne q{}){
         $fld->update('o' => $data[3] );
      }

      if ($data[4] ne q{}){
         $fld->update( 'o' => 'Subject file: '.$data[4] );
      }
      $rec->insert_grouped_field($fld);
   }

   $debug and print $rec->as_formatted()."\n\n";
   print {$out} $rec->as_usmarc();
   $written++;
}

close $out;
close $in;

print "\n\n$i records read.\n$written records written.\n";

exit;

sub _process_date {
   my $date = shift;
   return if $date eq q{};
   my ($month,$day,$year) = split '/', $date;
   if ($year <=12 ) {
      $year += 2000;
   }
   if ($year < 100) {
     $year += 1900;
   }
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}

