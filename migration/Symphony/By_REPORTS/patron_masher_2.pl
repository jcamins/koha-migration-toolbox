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
use Encode;
use Getopt::Long;
use Text::CSV;
use Text::CSV::Simple;
$|=1;
my $debug=0;

my $infile_name = "";
my $outfile_name = "";
my $fixed_branch = "";
my $branch_map_name = "";
my %branch_map;
my $mapfile_name = "";
my %patron_cat_map;
my $default_privacy = "";
my $drop_code_str = "";
my %drop_codes;

GetOptions(
    'in=s'          => \$infile_name,
    'out=s'         => \$outfile_name,
    'map=s'         => \$mapfile_name,
    'branch=s'      => \$fixed_branch,
    'branch_map=s'  => \$branch_map_name,
    'default_privacy=s' => \$default_privacy,
    'drop_codes=s'  => \$drop_code_str,
    'debug'         => \$debug,
);

if (($infile_name eq '') || ($outfile_name eq '')){
  print "Something's missing.\n";
  exit;
}
if ($drop_code_str){
   foreach my $code (split(/,/,$drop_code_str)){
      $drop_codes{$code} = 1;
   }
}
if ($branch_map_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$branch_map_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $branch_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

if ($mapfile_name){
   my $csv = Text::CSV->new();
   open my $mapfile,"<$mapfile_name";
   while (my $row = $csv->getline($mapfile)){
      my @data = @$row;
      $patron_cat_map{$data[0]} = $data[1];
   }
   close $mapfile;
}

open my $infl,"<$infile_name" || die ('problem opening $infile_name');
my $i=0;
my $written=0;

my %thisrow;
my $addedcode;
my %patron_categories;
my %patron_branches;
my %patron_cat1s;
my %patron_cat2s;
my %patron_cat3s;
my %taggs;
my $address_toggle=0;

my @borrower_fields = qw /cardnumber          surname 
                          firstname           title 
                          othernames          initials 
                          streetnumber        streettype 
                          address             address2
                          city                zipcode 
                          country             email 
                          phone               mobile 
                          fax                 emailpro 
                          phonepro            B_streetnumber 
                          B_streettype        B_address 
                          B_address2          B_city 
                          B_zipcode           B_country 
                          B_email             B_phone 
                          dateofbirth         branchcode 
                          categorycode        dateenrolled 
                          dateexpiry          gonenoaddress 
                          lost                debarred 
                          contactname         contactfirstname 
                          contacttitle        guarantorid
                          borrowernotes       relationship 
                          ethnicity           ethnotes 
                          sex                 password 
                          flags               userid 
                          opacnote            contactnote        
                          sort1               sort2             
                          altcontactfirstname altcontactsurname  
                          altcontactaddress1  altcontactaddress2 
                          altcontactaddress3  altcontactzipcode 
                          altcontactcountry   altcontactphone
                          smsalertnumber      state
                          altcontactstate     altcontactcity
                          B_state             privacy /;

open my $out,">:utf8",$outfile_name;
for my $j (0..scalar(@borrower_fields)-1){
   print $out $borrower_fields[$j].',';
}
print $out "patron_attributes\n";
open my $notes,">:utf8","patron_notes.csv";

LINE:
while (my $line = readline($infl)){
   last LINE if ($debug && $written >50);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);

   chomp $line;
   $line =~ s///g;
   next LINE if $line eq q{};
   next LINE if substr $line, 0, 1 eq '*';
   next LINE if $line =~ /User List/;
   next LINE if $line =~ /   Produced/;
   next LINE if $line =~ /cat4:/;
   next LINE if $line =~ /PREV_ID:/;
   next LINE if $line =~ /   bills:/;
   next LINE if $line =~ /   total bills:/;
   next LINE if $line =~ /number of history charges:/;
   next LINE if $line =~ /  user access/;
   next LINE if $line =~ /GEAC status:/;
   next LINE if $line =~ /   none$/;
   $line =~ s/^[\w\.]+//g;

   if ($line =~ /address1:/){
      $address_toggle="";
      next LINE;
   }
   
   if ($line =~ /address2:/){
      $address_toggle='B_';
      next LINE;
   }
  
   if ($line =~ /address3:/){
      $address_toggle='altcontact';
      next LINE;
   }

   if ($line =~ /^ [A-Za-z]/ || $line =~ /^  [A-Za-z]/){
      $line =~ s/^\s+//;
      ($thisrow{surname},$thisrow{firstname}) = split /,/, $line;
      if ($thisrow{firstname}){
         $thisrow{firstname} =~ s/^\s+//;
      }
      next LINE;
   }

   if ($line =~ /^\s+Profile:(\w+)\s+status:(\w+)/){
      $thisrow{categorycode} = $1;
      my $tmpstatus= $2;
      if ($tmpstatus eq "BARRED"){
         $thisrow{debarred} = 1;
      }
      next LINE;
   }

   if ($line =~ /^\s+id:(\w+)\s+library:(\w+)/){
      $thisrow{cardnumber} = $1;
      $thisrow{branchcode} = $2;
      next LINE;
   }

   if ($line =~ /^\s+cat1:(.+)cat2:(.+)cat3:(.+)/){
      my ($cat1,$cat2,$cat3) = ($1,$2,$3);
      $cat1 =~ s/\s+$//g;
      $cat2 =~ s/\s+$//g;
      $cat3 =~ s/\s+$//g;
      if ($cat1 ne q{}){
         $addedcode .= ",CAT1:$cat1";
         $patron_cat1s{$cat1}++;
      }
      if ($cat2 ne q{}){
         $addedcode .= ",CAT2:$cat2";
         $patron_cat2s{$cat2}++;
      }
      if ($cat3 ne q{}){
         $addedcode .= ",CAT3:$cat3";
         $patron_cat3s{$cat3}++;
      }
      $addedcode =~ s/^,//; 
      next LINE;
   }

   if ($line =~ /^\s+id:(\w+)\s+alt id:.+library:(\w+)/){
      $thisrow{cardnumber} = $1;
      $thisrow{branchcode} = $2;
      next LINE;
   }

   if ($line =~ /priv granted:([0-9\/]+)/){
      $thisrow{dateenrolled} = _process_date($1);
      next LINE;
   }

   if ($line =~ /priv expired:([0-9\/]+)/){
      $thisrow{dateexpiry} = _process_date($1);
      next LINE;
   }
  
   if ($line =~ / ADDRESS:(.+)/){
      $thisrow{$address_toggle.'address'}=$1;
      next LINE;
   }

   if ($line =~ / Street:(.+)/){
      $thisrow{$address_toggle.'address'}=$1;
      next LINE;
   }

   if ($line =~ / City:(.+)/){
      ($thisrow{$address_toggle.'city'},$thisrow{$address_toggle.'state'})=split (/,/,$1);
      if ($thisrow{$address_toggle.'state'}){
         $thisrow{$address_toggle.'state'} =~ s/^\s+//;
      }
      next LINE;
   }

   if ($line =~ / City, State:(.+)/){
      ($thisrow{$address_toggle.'city'},$thisrow{$address_toggle.'state'})=split (/,/,$1);
      if ($thisrow{$address_toggle.'state'}){
         $thisrow{$address_toggle.'state'} =~ s/^\s+//;
      }
      next LINE;
   }

   if ($line =~ / Zip:(.+)/){
      $thisrow{$address_toggle.'zipcode'}=$1;
      next LINE;
   }

   if ($line =~ / Postal Code:(.+)/){
      $thisrow{$address_toggle.'zipcode'}=$1;
      next LINE;
   }
   
   if ($line =~ /   FAX:(.+)/){
      $thisrow{fax}=$1;
      next LINE;
   }

   if ($line =~ /Work Phone:(.+)/){
      $thisrow{phonepro}=$1;
      next LINE;
   }

   if ($line =~ /   Phone:(.+)/){
      $thisrow{phone}=$1;
      next LINE;
   }

   if ($line =~ /Home Phone:(.+)/){
      $thisrow{phone}=$1;
      next LINE;
   }

   if ($line =~ /   Daytime Phone:(.+)/){
      $thisrow{phone}=$1;
      next LINE;
   }
 
   if ($line =~ /Email:(.+)/){
      $thisrow{email}=$1;
      next LINE;
   }

   if ($line =~ /Comment:(.+)/){
      my $note = $1;
      $note =~ s/\"//g;
      print $notes "$thisrow{cardnumber},$note\n";
      next LINE;
   }
 
   if ($line =~ /Note:(.+)/){
      my $note = $1;
      $note =~ s/\"//g;
      print $notes "$thisrow{cardnumber},$note\n";
      next LINE;
   }
 
   if ($line =~ /parent:(.+)/){
      my $note = $1;
      $note =~ s/\"//g;
      print $notes "$thisrow{cardnumber},Parent: $note\n";
      next LINE;
   }
 
   if ($line =~ /   dept:/){
      $thisrow{altcontactaddress1} = $thisrow{altcontactaddress};
      $thisrow{altcontactaddress2} = $thisrow{altcontactaddress2};
      $thisrow{altcontactaddress3} = $thisrow{altcontactcity};
      $thisrow{userid} = $thisrow{cardnumber};
      $thisrow{password} = substr $thisrow{cardnumber},-4;

      if (!$thisrow{surname}){
         $thisrow{surname} = "NONAME";
      }

      if ($patron_cat_map{$thisrow{categorycode}}){
         $thisrow{categorycode} = $patron_cat_map{$thisrow{categorycode}};
      }

      if ($fixed_branch && $thisrow{branchcode} eq q{} ){
         $thisrow{branchcode} = $fixed_branch;
      } 

      if ($branch_map{$thisrow{branchcode}}){
         $thisrow{branchcode} = $branch_map{$thisrow{branchcode}};
      }
    
      if ($default_privacy ne q{}){
         $thisrow{privacy} = $default_privacy;
      }

      if (!$drop_codes{$thisrow{categorycode}}){
         $patron_categories{$thisrow{categorycode}}++;
         $patron_branches{$thisrow{branchcode}}++;
         for my $j (0..scalar(@borrower_fields)-1){
            if ($thisrow{$borrower_fields[$j]}){
               $thisrow{$borrower_fields[$j]} =~ s/\"/'/g;
               if ($thisrow{$borrower_fields[$j]} =~ /,/){
                  print $out '"'.$thisrow{$borrower_fields[$j]}.'"';
               }
               else{
                  print $out $thisrow{$borrower_fields[$j]};
               }
            }
            print $out ",";
         }
         if ($addedcode){
             print $out '"'."$addedcode".'"';
         }
         print $out "\n";
         $written++;
      }
      %thisrow=();
      $address_toggle=0;
      $addedcode = q{};
      next LINE;
   }

   if ($line =~ /^\s{26}\S+/){
      my $note = $line;
      $note =~ s/^\s+//g;
      print $notes "$thisrow{cardnumber},$note\n";
      next LINE;
   }

   if ($line =~ /^\s+([\w, ]+):/){
      $taggs{$1}++;
      next LINE;
   }
}

close $infl;
close $out;

print "\n\n$i lines read.\n$written borrowers written.\n";
print "\nRemaining tags by tags:\n";
foreach my $kee (sort keys %taggs){
    print $kee.":  ".$taggs{$kee}."\n";
}
print "\nResults by branchcode:\n";
foreach my $kee (sort keys %patron_branches){
    print $kee.":  ".$patron_branches{$kee}."\n";
}
open my $sql,">patron_sql.sql";
print "\nResults by categorycode:\n";
foreach my $kee (sort keys %patron_categories){
    print $kee.":  ".$patron_categories{$kee}."\n";
    print $sql "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}
print "\nResults by cat1:\n";
foreach my $kee (sort keys %patron_cat1s){
    print $kee.":  ".$patron_cat1s{$kee}."\n";
    print $sql "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CAT1','$kee','$kee');";
}
print "\nResults by cat2:\n";
foreach my $kee (sort keys %patron_cat2s){
    print $kee.":  ".$patron_cat2s{$kee}."\n";
    print $sql "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CAT2','$kee','$kee');";
}
print "\nResults by cat3:\n";
foreach my $kee (sort keys %patron_cat3s){
    print $kee.":  ".$patron_cat3s{$kee}."\n";
    print $sql "INSERT INTO authorised_values (category,authorised_value,lib) VALUES ('CAT3','$kee','$kee');";
}
close $sql;

exit;

sub _process_date {
   my $datein= shift;
   return undef if ($datein eq q{});
   my ($month,$day,$year) = split /\//,$datein;
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
