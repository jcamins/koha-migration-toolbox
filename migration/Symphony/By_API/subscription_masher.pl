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
use C4::Context;

my $infile_name = "";
my $outfile_name = "";
my $outfile2_name = "";
my $branch_mapfile;
my %branch_map;
my $names_file = "";
my $statusfile_name ="";
my %names;
my $catkey_file = "";
my %catkeys;

GetOptions(
    'in=s'            => \$infile_name,
    'out=s'           => \$outfile_name,
    'out2=s'           => \$outfile2_name,
    'names=s'         => \$names_file,
    'status=s'        => \$statusfile_name,
    'catkeys=s'       => \$catkey_file,
    'branch_map=s'    => \$branch_mapfile,
    'debug'           => \$debug,
);

if (($infile_name eq q{}) || ($outfile_name eq q{}) ){
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

if ($names_file ne q{}){
   open my $mapfile,'<',$names_file;
   while (my $row = readline($mapfile)){
      my @data=split /\|/, $row;
      $names{$data[0]}{$data[1]} = $data[2];
   }
   close $mapfile;
}
if ($catkey_file){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$catkey_file";
   while (my $row = $csv->getline($mapfile)){
      my @data=@$row;
      $catkeys{$data[0]} = $data[1];
   }
   close $mapfile;
}

my $i=0;
my $j=0;
my $problem=0;
my %this_subscription = ();
$this_subscription{internalnotes} = "";
my $vendlib = "";
my $vendid = "";
my $use1 =0;
my $note=0;
my $use2 =0;
my $stat = "";
my $id = "";
my $dbh = C4::Context->dbh();
my $vendor_sth= $dbh->prepare("SELECT id from aqbooksellers where name = ?");
my @subscription_fields = qw / subscriptionid    branchcode
                               biblionumber  callnumber
                               internalnotes   status
                               startdate   aqbooksellerid
                               numberingmethod  notes
                             /;

open my $out,">:utf8",$outfile_name;
open my $out2,">:utf8",$outfile2_name;
open my $status,'>',$statusfile_name;
for my $k (0..scalar(@subscription_fields)-1){
   print $out $subscription_fields[$k].',';
}
print $out "\n";
print $out2 "biblionumber,subscriptionid,histstartdate\n";

open my $in,"<$infile_name";
while (my $line = readline($in)) {
   last if ($debug && $j>9);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($line =~ /DOCUMENT BOUNDARY/){
      next if $i==1;
      if ($this_subscription{biblionumber}){
         $j++;
         if (exists $branch_map{$this_subscription{branchcode}}){
            $this_subscription{branchcode} = $branch_map{$this_subscription{branchcode}};
         }

         if (exists $names{$vendlib}{$vendid}){
            $vendor_sth->execute($names{$vendlib}{$vendid});
            my $vendor= $vendor_sth->fetchrow_hashref();
            $this_subscription{aqbooksellerid} = $vendor->{id};
         }

         $this_subscription{'internalnotes'} =~ s/^ \-\- //;

         print $status "$id,$stat\n";
         print $out2 "$this_subscription{biblionumber},$this_subscription{subscriptionid},$this_subscription{startdate}\n";
    
         for my $k (0..scalar(@subscription_fields)-1){
            if ($this_subscription{$subscription_fields[$k]}){
               $this_subscription{$subscription_fields[$k]} =~ s/\"/'/g;
               if ($this_subscription{$subscription_fields[$k]} =~ /,/){
                  print $out '"'.$this_subscription{$subscription_fields[$k]}.'"';
               }
               else{
                  print $out $this_subscription{$subscription_fields[$k]};
               }
            }
            print $out ",";
         }
         print $out "\n";
      }         
      else{
         print "Problem!\n";
         print Dumper(%this_subscription);
         $problem++;
      }
      %this_subscription=();
      $this_subscription{internalnotes} = "";
      $vendlib = "";
      $vendid = "";
      $use1=0;
      $use2= 0;
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
   if  ($thistag eq "NOTE") {
      $this_subscription{'internalnotes'} .= " -- ".$content." ";
      $note = 1;
      next;
   }
   if (($thistag eq "") && $note){
      $this_subscription{'internalnotes'} .= $line." ";
      next;
   }

   if ($thistag eq "SERC_ID"){
      $this_subscription{subscriptionid} = $content;
      $id = $content;
      next;
   }

   if ($thistag eq "SERC_STATUS") {
      $stat= $content;
      next;
   }
   if ($thistag eq "VENDOR_ID"){
      $vendid= $content;
      next;
   }
   
   if ($thistag eq "VEND_LIBR"){
      $vendlib = $content;
      next;
   }

   if ($thistag eq "SERC_TITLE_KEY"){
      $this_subscription{biblionumber} = $catkeys{$content};
      next;
   }

   if ($thistag eq "BASE_CALLNUM"){
      $this_subscription{callnumber} = $content;
      next;
   }
  
   if ($thistag eq "SISAC_ID"){
      $this_subscription{'internalnotes'} .= " -- SISAC: ".$content." ";
      next;
   }

   if ($thistag eq "SERC_DATE_CREATED") {
      $this_subscription{'startdate'} = _process_date($content);
      next;
   }

   if ($thistag eq "PHYSFORM") {
      $this_subscription{'notes'} = $content;
      next;
   }
  
   if ($thistag eq "SERC_LIB") {
      $this_subscription{branchcode} = $content;
      next;
   }
 
   if ($thistag eq "SERC_USE1") {
      $use1 = 1;
     next;
   }
  
   if (($thistag eq "SERC_LBL1") && $use1){
      $this_subscription{numberingmethod} = $content.' {X}';
      next;
   }

   if ($thistag eq "SERC_USE2") {
      $use2 = 1;
     next;
   }
  
   if (($thistag eq "SERC_LBL2") && $use2){
      $this_subscription{numberingmethod} .= ', '.$content.' {Y}';
      next;
   }

}
      if ($this_subscription{biblionumber}){
         $j++;
         if (exists $branch_map{$this_subscription{branchcode}}){
            $this_subscription{branchcode} = $branch_map{$this_subscription{branchcode}};
         }

         if (exists $names{$vendlib}{$vendid}){
            $vendor_sth->execute($names{$vendlib}{$vendid});
            my $vendor= $vendor_sth->fetchrow_hashref();
            $this_subscription{aqbooksellerid} = $vendor->{id};
         }

         $this_subscription{'internalnotes'} =~ s/^ \-\- //;

         print $status "$id,$stat\n";
    
         for my $k (0..scalar(@subscription_fields)-1){
            if ($this_subscription{$subscription_fields[$k]}){
               $this_subscription{$subscription_fields[$k]} =~ s/\"/'/g;
               if ($this_subscription{$subscription_fields[$k]} =~ /,/){
                  print $out '"'.$this_subscription{$subscription_fields[$k]}.'"';
               }
               else{
                  print $out $this_subscription{$subscription_fields[$k]};
               }
            }
            print $out ",";
         }
         print $out "\n";
      }         
      else{
         print "Problem!\n";
         print Dumper(%this_subscription);
         $problem++;
      }


close $out;

print "\n\n$i lines read.\n$j subscriptions found.\n$problem problems found.\n";
exit;

sub _process_date {
    my ($date_in) = @_;
    return "" if ($date_in eq "NEVER");
    my $year = substr($date_in,0,4);
    my $month = substr($date_in,4,2);
    my $day = substr($date_in,6,2);
    return sprintf "%d-%02d-%02d",$year,$month,$day;
}

