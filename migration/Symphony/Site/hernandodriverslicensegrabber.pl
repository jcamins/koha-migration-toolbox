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
use Data::Dumper;
use Getopt::Long;
use Text::CSV;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";

GetOptions(
    'in=s'            => \$infile_name,
    'out=s'           => \$outfile_name,
    'debug'           => \$debug,
);
if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}

open my $in,"<$infile_name";
my $i=0;
my $j=0;
my @borrowers;
my $license;
my $note;
my %thisborrower = ();
my $toss_this_borrower;
my $borrowers_tossed;
my %headerkees;

while (my $line = readline($in)) {
   last if ($debug && $j>9);
   chomp $line;
   $line =~ s///g;
   $i++;
   print ".";
   print "\r$i" unless $i % 100;
   if ($line =~ /DOCUMENT BOUNDARY/){
      $toss_this_borrower++ if (!$thisborrower{'license'});
      if (%thisborrower && !$toss_this_borrower){
         $j++;
         push @borrowers,{%thisborrower};
         foreach my $kee ( sort keys %thisborrower){
            $headerkees{$kee} = 1;
         }
      }
      print Dumper(%thisborrower) if ($thisborrower{'cardnumber'} eq "3755");
      $borrowers_tossed++ if ($toss_this_borrower);
      $note = 0;
      $license = 0;
      $toss_this_borrower=0;
      %thisborrower=();
      next;
   }
   next if ($toss_this_borrower);
   $debug and print $line."\n";
   $line =~ /^\.([\w\/]+)\./;
   my $thistag = $1;
   $line =~ /\|a(.*)$/;
   my $content = $1;
   $debug and print "$thistag ~~ $content ~~\n";

   $note = 0 if ($thistag);
   $thisborrower{'cardnumber'} = $content if ($thistag eq "USER_ID");
   $thisborrower{'license'} = $content if ($thistag eq "LICENSE");

#   if ($thistag eq "LICENSE"){
#      $license=1;
#      next;
#   }
#   
#   if ($license){
#      $debug and print $line."\n" if ($thistag eq "");
#      $thisborrower{'license'} = $content if ($thistag eq "LICENSE");
#      next;
#   }
  
   $debug and print $line if ($thistag eq "");
}
$toss_this_borrower++ if (!$thisborrower{'license'});
if (%thisborrower && !$toss_this_borrower){
   $j++;
   push @borrowers,{%thisborrower};
   foreach my $kee ( sort keys %thisborrower){
      $headerkees{$kee} = 1;
   }
}


print "\n\n$i lines read.\n$j borrowers found.\n$borrowers_tossed borrowers tossed out.\n";

open my $out,">$outfile_name";
foreach my $kee (sort keys %headerkees){
   print $out $kee.",";
}
print $out "\n";
for (my $j=0;$j<scalar(@borrowers);$j++){
   foreach my $kee (sort keys %headerkees){
      $borrowers[$j]{$kee} =~ s/\"/'/g;
      if ($borrowers[$j]{$kee} =~ /,/){
         print $out '"'.$borrowers[$j]{$kee}.'",';
         next;
      }
      else{
         if ($borrowers[$j]{$kee}){
            print $out $borrowers[$j]{$kee};
         }
         print $out ",";
      }
   }
   print $out "\n";
}
close $in;
close $out;
exit;

sub _process_date {
    my ($date_in) = @_;
    return "" if ($date_in eq "NEVER");
    my $year = substr($date_in,0,4);
    my $month = substr($date_in,4,2);
    my $day = substr($date_in,6,2);
    return sprintf "%d-%02d-%02d",$year,$month,$day;
}

