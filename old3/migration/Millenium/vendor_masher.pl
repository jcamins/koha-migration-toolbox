#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV;
use Text::CSV::Simple;
local $OUTPUT_AUTOFLUSH = 1;
my $debug=0;
Readonly my $FIELD_SEPARATOR => q{$};

my $infile_name = q{};
my $outfile_name = q{};
my $fixed_currency = q{};

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'currency=s'    => \$fixed_currency,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

my $i=0;
my $written=0;

my $csv_format = Text::CSV::Simple->new();
$csv_format->field_map( qw(null null null
                           null null null
                           code name acctnum
                           contact addr1 addr2
                           null phone fax
                           email note1 note2 
                           special null) );


my @bookseller_fields = qw /name address1 active currency
                            phone    accountnumber listprice invoiceprice 
                            fax notes contemail
                            url contact contpos
                            contphone contnotes postal/;

open my $out,">:utf8",$outfile_name || croak "$outfile_name: $!";
for my $j (0..scalar(@bookseller_fields)-1){
   print $out $bookseller_fields[$j].',';
}
print $out "\n";

open my $infl,"<",$infile_name || croak "$infile_name: $!";
RECORD:
for my $row ($csv_format->read_file($infl)){
   my %thisrow;
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);

   my @notes;
   my $note="";

   next RECORD if (!$row->{code} || !$row->{name});

   $thisrow{contnotes} = $row->{code};
   $thisrow{name} = $row->{name};
   $row->{addr1} =~ s/\$/\n/gx;
   $thisrow{postal} = $row->{addr1};
   if ($row->{addr2} ne '$$$'){
      $row->{addr2} =~ s/\$/\n/gx;
      $thisrow{address1} = $row->{addr2};
   }
   $thisrow{phone} = $row->{phone};
   $thisrow{accountnumber} = $row->{acctnum};
   $thisrow{fax} = $row->{fax};
   $thisrow{contemail} = $row->{email};
   ($thisrow{contact},$thisrow{contpos},
    $thisrow{contphone}) = split $FIELD_SEPARATOR ,$row->{contact},3;

   if ($row->{note1} ne q{}){
      if ($row->{note1} =~ m/\.com|\.org|^www/x){
         $thisrow{url} = $row->{note1};
      }
      else {
         push @notes, $row->{note1};
      }
   }

   if ($row->{note2} ne q{}){
      push @notes, $row->{note2};
   }

   if ($row->{special} ne q{}){
      push @notes, $row->{special};
   }

   $thisrow{notes} = join '\n',@notes;
   $thisrow{active} = 1;

   if ($fixed_currency){
      $thisrow{currency} = $fixed_currency;
      $thisrow{listprice} = $fixed_currency;
      $thisrow{invoiceprice} = $fixed_currency;
   }
   for my $j (0..scalar(@bookseller_fields)-1){
      if ($thisrow{$bookseller_fields[$j]}){
         $thisrow{$bookseller_fields[$j]} =~ s/\"/'/gx;
         if ($thisrow{$bookseller_fields[$j]} =~ /,|\n/x){
            print $out '"'.$thisrow{$bookseller_fields[$j]}.'"';
         }
         else{
            print $out $thisrow{$bookseller_fields[$j]};
         }
      }
      print $out ",";
   }
   print $out "\n";
   $written++;
}
close $infl;
close $out;

print "\n\n$i lines read.\n$written booksellers written.\n";
exit;
