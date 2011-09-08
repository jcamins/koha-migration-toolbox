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
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $create = 0;
my $branch_mapfile;
my %branch_map;
my $currency_mapfile;
my %currency_map;
my $names_file = "";

GetOptions(
    'in=s'            => \$infile_name,
    'out=s'           => \$outfile_name,
    'branch_map=s'    => \$branch_mapfile,
    'currency_map=s'  => \$currency_mapfile,
    'names=s'         => \$names_file,
    'debug'           => \$debug,
);

if (($infile_name eq q{}) || ($outfile_name eq q{}) || ($names_file eq q{})){
  print "Something's missing.\n";
  exit;
}

if ($branch_mapfile){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$branch_mapfile";
   while (my $row = $csv->getline($mapfile)){
      my @data=@$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($currency_mapfile){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$currency_mapfile";
   while (my $row = $csv->getline($mapfile)){
      my @data=@$row;
      $currency_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

my %names;
print "Reading in vendor name/ID mapping:\n";
my $j=0;
open my $namefile,"<",$names_file;
while ( my $line = readline($namefile)){
   $j++;
   print "." unless $j % 10;
   print "\r$j" unless $j % 100;
   chomp $line;
   my ($lib,$id,$name,undef)=split(/\|/,$line);
   $names{$lib}{$id} = $name;
}
print "\n$j names read.\n";

print "Processing vendor data:\n";
my $i=0;
$j=0;
my $addr_code;
my $serviceaddr=0;
my $orderaddr=0;
my @addr_line;
my %address;
my $note;
my %thisvendor = ();
my @vendor_fields = qw / name
                         address1        address2
                         address3        address4
                         phone           accountnumber
                         othersupplier   currency
                         booksellerfax   notes
                         bookselleremail booksellerurl
                         contact         postal
                         url             contpos
                         contphone       contfax
                         contaltphone    contemail
                         contnotes       active
                         listprice       invoiceprice
                         gstreg          listincgst
                         invoiceincgst   gstrate
                         discount        fax /;

open my $out,">:utf8",$outfile_name;
for my $k (0..scalar(@vendor_fields)-1){
   print $out $vendor_fields[$k].',';
}
print $out "\n";

open my $in,"<$infile_name";
while (my $line = readline($in)) {
   last if ($debug && $j>9);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($line =~ /DOCUMENT BOUNDARY/){
      if (%thisvendor){
         $j++;
         $thisvendor{active} = 1;
         $thisvendor{name} = $names{$thisvendor{branchcode}}{$thisvendor{idnum}};
         if (exists $branch_map{$thisvendor{branchcode}}){
            $thisvendor{branchcode} = $branch_map{$thisvendor{branchcode}};
         }
         $thisvendor{phone}   = $address{$thisvendor{accountaddr}}{phone} || $address{$thisvendor{serviceaddr}}{phone};
         $thisvendor{contact} = $address{$thisvendor{accountaddr}}{attn} || $address{$thisvendor{serviceaddr}}{attn};
         $thisvendor{fax}     = $address{$thisvendor{accountaddr}}{fax} || $address{$thisvendor{serviceaddr}}{fax};
         
         $thisvendor{contphone} = $address{$thisvendor{serviceaddr}}{phone};
         $thisvendor{contemail} = $address{$thisvendor{serviceaddr}}{email};
         $thisvendor{contfax}   = $address{$thisvendor{serviceaddr}}{fax};

         if (exists $addr_line[$thisvendor{serviceaddr}][0]){
            $thisvendor{postal} = join('\\\\n',@{$addr_line[$thisvendor{serviceaddr}]});
         }
         $thisvendor{address1} = $addr_line[$thisvendor{accountaddr}][0] || undef;
         $thisvendor{address2} = $addr_line[$thisvendor{accountaddr}][1] || undef;
         $thisvendor{address3} = $addr_line[$thisvendor{accountaddr}][2] || undef;
         $thisvendor{address4} = $addr_line[$thisvendor{accountaddr}][3] || undef;
         if (scalar @{$addr_line[$thisvendor{accountaddr}]} >4){
            for my $k (4..scalar @{$addr_line[$thisvendor{accountaddr}]} -1){
               $thisvendor{address4} .= '\\\\n'.$addr_line[$thisvendor{accountaddr}][$k];
            }
         }

         if ($thisvendor{name} =~ /^Best/){
            print Dumper(%thisvendor);
            print Dumper(%address);
            print Dumper(@addr_line);
         }       

         for my $k (0..scalar(@vendor_fields)-1){
            if ($thisvendor{$vendor_fields[$k]}){
               $thisvendor{$vendor_fields[$k]} =~ s/\"/'/g;
               if ($thisvendor{$vendor_fields[$k]} =~ /,/){
                  print $out '"'.$thisvendor{$vendor_fields[$k]}.'"';
               }
               else{
                  print $out $thisvendor{$vendor_fields[$k]};
               }
            }
            print $out ",";
         }
         print $out "\n";
      }         
      $note = 0;
      $addr_code = 0;
      @addr_line= ();
      %address=();
      $serviceaddr=0;
      $orderaddr=0;
      %thisvendor=();
      next;
   }
   $debug and print $line."\n";
   $line =~ /^\.([\w\/]+)\./;
   my $thistag = $1;
   $line =~ /\|a(.*)$/;
   my $content = $1;
   next if (!$content);
   $debug and print "$thistag ~~ $content ~~\n";
   
   $note = 0 if ($thistag);
   if ( ($thistag eq "NOTE") or ($thistag eq "COMMENT") ){
      $thisvendor{'notes'} .= " -- " if $thisvendor{'notes'};
      $thisvendor{'notes'} .= $content." ";
      $note = 1;
      next;
   }
   if (($thistag eq "") && $note){
      $thisvendor{'notes'} .= $line." ";
      next;
   }

   if ($thistag eq "VEND_ID"){
      $thisvendor{'idnum'} = $content;
   }
   
   if ($thistag eq "VEND_LIBRARY"){
      $thisvendor{'branchcode'} = $content;
   }

   if ($thistag eq "VEND_CUSTOMER"){
      $thisvendor{'accountnumber'} = $content;
   }

   if ($thistag eq "VEND_CURRENCY"){
      if (exists $currency_map{$content}){
         $content = $currency_map{$content};
      }
      $thisvendor{'currency'} = $content;
      $thisvendor{'listprice'} = $content;
      $thisvendor{'invoiceprice'} = $content;
   }

   if ($thistag eq "VEND_ACCOUNTADDR"){
      $thisvendor{accountaddr} = $content;
   }

   if ($thistag eq "VEND_SERVICEADDR"){
      $thisvendor{serviceaddr} = $content;
   }

   if ($thistag eq "VEND_ADDR1_BEGIN"){
      $addr_code=1;
      next;
   }
   if ($thistag eq "VEND_ADDR1_END"){
      $addr_code=0;
      next;
   }
   if ($thistag eq "VEND_ADDR2_BEGIN"){
      $addr_code=2;
      next;
   }
   if ($thistag eq "VEND_ADDR2_END"){
      $addr_code=0;
      next;
   }
   if ($thistag eq "VEND_ADDR3_BEGIN"){
      $addr_code=3;
      next;
   }
   if ($thistag eq "VEND_ADDR3_END"){
      $addr_code=0;
      next;
   }
   if ($addr_code){
      $debug and print $line."\n" if ($thistag eq "");
      if ($thistag eq "EMAIL"){
         if ($content =~ /@/){
            $address{$addr_code}{email} = $content;
         }
         else{
            $thisvendor{url} = $content;
         }
         next;
      }
      if ($thistag eq "FAX"){
         $address{$addr_code}{fax} = $content;
         next;
      }
      if ($thistag eq "PHONE"){
         $address{$addr_code}{phone} = $content;
         next;
      }
      if ($thistag eq "ATTN"){
         $address{$addr_code}{attn} = $content;
         next;
      }
      push @{$addr_line[$addr_code]},$content;
      next;
   }
}

if (%thisvendor){
   $j++;
   $thisvendor{active} = 1;
   $thisvendor{name} = $names{$thisvendor{branchcode}}{$thisvendor{idnum}};
   if (exists $branch_map{$thisvendor{branchcode}}){
      $thisvendor{branchcode} = $branch_map{$thisvendor{branchcode}};
   }
   $thisvendor{phone}   = $address{$thisvendor{accountaddr}}{phone};
   $thisvendor{contact} = $address{$thisvendor{accountaddr}}{attn};
   $thisvendor{fax}     = $address{$thisvendor{accountaddr}}{fax};

   $thisvendor{contphone} = $address{$thisvendor{serviceaddr}}{phone};
   $thisvendor{contemail} = $address{$thisvendor{serviceaddr}}{email};
   $thisvendor{contfax}   = $address{$thisvendor{serviceaddr}}{fax};

   $thisvendor{postal} = join('\\n',@{$addr_line[$thisvendor{serviceaddr}]});
   $thisvendor{address1} = $addr_line[$thisvendor{accountaddr}][0] || undef;
   $thisvendor{address2} = $addr_line[$thisvendor{accountaddr}][1] || undef;
   $thisvendor{address3} = $addr_line[$thisvendor{accountaddr}][2] || undef;
   $thisvendor{address4} = $addr_line[$thisvendor{accountaddr}][3] || undef;
   if (scalar @{$addr_line[$thisvendor{accountaddr}]} >4){
      for my $k (4..scalar @{$addr_line[$thisvendor{accountaddr}]}-1){
         $thisvendor{address4} .= '\\n'.$addr_line[$thisvendor{accountaddr}][$k];
      }
   }

   for my $k (0..scalar(@vendor_fields)-1){
      if ($thisvendor{$vendor_fields[$k]}){
         $thisvendor{$vendor_fields[$k]} =~ s/\"/'/g;
         if ($thisvendor{$vendor_fields[$k]} =~ /,/){
            print $out '"'.$thisvendor{$vendor_fields[$k]}.'"';
         }
         else{
            print $out $thisvendor{$vendor_fields[$k]};
         }
      }
      print $out ",";
   }
   print $out "\n";
}

close $out;

print "\n\n$i lines read.\n$j vendors found.\n";
exit;
