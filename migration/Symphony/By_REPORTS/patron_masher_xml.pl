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
#
# EXPECTS:
#   -input XML from Symphony
#
# DOES:
#   -nothing
#
# CREATES:
#   -patron CSV
#
# REPORTS:
#   -count of borrowers read
#   -count of borrowers written

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use XML::Simple;

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

my $input_filename  = $NULL_STRING;
my $output_filename = $NULL_STRING;
my $codes_filename  = '/dev/null';
my $tally_fields    = $NULL_STRING;
my @col;
my @addrcol;
my @static;
my @datamap_filenames;

GetOptions(
    'in=s'     => \$input_filename,
    'out=s'    => \$output_filename,
    'codes=s'  => \$codes_filename,
    'tally=s'  => \$tally_fields,
    'col=s'    => \@col,
    'addrcol=s' => \@addrcol,
    'static=s' => \@static,
    'map=s'    => \@datamap_filenames,
    'debug'    => \$debug,
);

for my $var ($input_filename,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my @field_mapping;
foreach my $map (@col) {
   my ($col, $field) = $map =~ /^(.*?):(.*)$/;
   if (!$col || !$field){
      croak ("--col=$map is ill-formed!\n");
   }
   push @field_mapping, {
      'column'    => $col,
      'field'     => $field,
   };
}

my @address_field_mapping;
foreach my $map (@addrcol) {
   my ($addr, $col, $field) = $map =~ /^(.*?):(.*?):(.*)$/;
   if (!$addr || !$col || !$field) {
      croak("--addrcol=$map is ill-formed!\n");
   }
   push @address_field_mapping, {
      'address'  => $addr,
      'column'   => $col,
      'field'    => $field,
   };
}

my @field_static;
foreach my $map (@static) {
   my ($field, $data) = $map =~ /^(.*?):(.*)$/;
   if (!$field || !$data) {
      croak ("--static=$map is ill-formed!\n");
   }
   push @field_static, {
      'field'  => $field,
      'data'      => $data,
   };
}

my %datamap;
foreach my $map (@datamap_filenames) {
   my ($mapsub,$map_filename) = split (/:/,$map);
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$map_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $datamap{$mapsub}{$data[0]} = $data[1];
   }
   close $mapfile;
}


my @borrower_fields = qw /cardnumber          surname
                          firstname           title
                          othernames          initials
                          streetnumber        streettype
                          address             address2
                          city                state
                          zipcode
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
                          smsalertnumber      privacy/;
my %tally;
my $dropped_by_type=0;

open my $output_file,'>:utf8',$output_filename;
for my $k (0..scalar(@borrower_fields)-1){
   print {$output_file} $borrower_fields[$k].',';
}
print {$output_file} "patron_attributes\n";

my $xml = XMLin($input_filename, ForceArray=>['userProfile'], 
                                 ForceArray=>['entry'], 
                                 SuppressEmpty => 1, 
                                 ContentKey => '-content');

RECORD:
foreach my $user (@{$xml->{user}}) {
   last RECORD if ($debug && $i>4);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   $debug and print Dumper($user);
   my %record;
   my $addedcode = $NULL_STRING;

   foreach my $map (@field_mapping) {
      #$debug and print Dumper($map);
      if (((defined $user->{$map->{'column'}}) && ($user->{$map->{'column'}} ne $NULL_STRING)) ||
          ((defined $user->{extendedInfo}->{entry}->{$map->{'column'}}) && ($user->{extendedInfo}->{entry}->{$map->{'column'}} ne $NULL_STRING))) {
         my $sub = $map->{'field'};
         #$debug and warn $sub;
         my $tool;
         my $appendflag;
         ($sub,$tool) = split (/~/,$sub,2);
         if ($sub =~ /\+$/) {
            $sub =~ s/\+//g;
            $appendflag=1;
         }

         my $data = $user->{$map->{'column'}} || $user->{extendedInfo}->{entry}->{$map->{'column'}};
         $data =~ s/^\s+//g;
         $data =~ s/\s+$//g;
         #$debug and print "$sub: $data\n";

         if ($data ne $NULL_STRING){
            if ($sub =~ /EXT/) {
               $sub =~ s/EXT://g;
               $addedcode .= ',' . $sub . ':'. $data;
            }
            elsif ($appendflag) {
               $record{$sub} .= ' ' .$data;
            }
            else {
               $record{$sub} = $data;
            }
         }
      }
   }

   foreach my $map (@address_field_mapping) {
      if (defined $user->{address}->{$map->{'address'}}->{entry}->{$map->{'column'}} &&
          $user->{address}->{$map->{'address'}}->{entry}->{$map->{'column'}} ne $NULL_STRING) {
         my $sub = $map->{'field'};
         my $tool;
         my $appendflag;
         ($sub,$tool) = split (/~/,$sub,2);
         if ($sub =~ /\+$/) {
            $sub =~ s/\+//g;
            $appendflag=1;
         }

         my $data = $user->{address}->{$map->{'address'}}->{entry}->{$map->{'column'}};
         $data =~ s/^\s+//g;
         $data =~ s/\s+$//g;
         #$debug and print "$sub: $data\n";

         if ($data ne $NULL_STRING){
            if ($sub =~ /EXT/) {
               $sub =~ s/EXT://g;
               $addedcode .= ',' . $sub . ':'. $data;
            }
            elsif ($appendflag) {
               $record{$sub} .= ' ' .$data;
            }
            else {
               $record{$sub} = $data;
            }
         }
      }
   }

   if (!defined $record{cardnumber}) {
      $record{cardnumber} = sprintf "TEMP%06d",$i;
   }
   $record{cardnumber} =~ s/ //g;

   $record{categorycode} = $user->{userProfile}[0];

   my $data=$user->{name}->{displayName} || $NULL_STRING;
   if ($data =~ m/\,/) {
      ($record{surname},$record{firstname}) = split /\,/,$data,2;
      $record{firstname} =~ s/^\s+//g;
   }
   else {
      $record{surname} = $data;
   }
   if ($record{firstname} && $record{firstname} =~ m/\(/) {
      ($record{firstname},$record{title}) = split /\(/,$record{firstname},2;
      $record{firstname} =~ s/\s+$//g;
      $record{title} =~ s/\)//g;
   }

   if ($record{city} && $record{city} =~ m/[\/,]/) {
      ($record{city},$record{state}) = split /[\/,]/,$record{city},2;
      $record{state} =~ s/^\s+//g;
      $record{state} =~ s/\s+$//g;
   }

   for my $tag (keys %record) {
      my $oldval = $record{$tag};
      if ($datamap{$tag}{$oldval}) {
         $record{$tag} = $datamap{$tag}{$oldval};
         if ($datamap{$tag}{$oldval} eq 'NULL') {
            delete $record{$tag};
         }
      }
   }

   foreach my $sub (split /,/, $tally_fields){
      if ($record{$sub}) {
         $tally{$sub}{$record{$sub}}++;
      }
   }

   if (!$record{categorycode}) {
      $dropped_by_type++;
      next RECORD;
   }

   $debug and print Dumper(%record);

   for $k (0..scalar(@borrower_fields)-1){
      if ($record{$borrower_fields[$k]}){
         $record{$borrower_fields[$k]} =~ s/\"/'/g;
         if ($record{$borrower_fields[$k]} =~ /,/){
            print {$output_file} '"'.$record{$borrower_fields[$k]}.'"';
         }
         else{
            print {$output_file} $record{$borrower_fields[$k]};
         }
      }
      print {$output_file} ",";
   }
   if ($addedcode){
      $addedcode =~ s/^,//;
      print {$output_file} '"'."$addedcode".'"';
   }
   print {$output_file} "\n";
   $written++;
}
close $output_file;

print << "END_REPORT";

$i records read.
$written records written.
$dropped_by_type records tossed due to categorycode.
$problem records not loaded due to problems.
END_REPORT

open my $codes_file,'>',$codes_filename;
foreach my $kee (sort keys %{ $tally{branchcode} } ){
   print {$codes_file} "INSERT INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
foreach my $kee (sort keys %{ $tally{categorycode} } ){
   print {$codes_file} "INSERT INTO categories (categorycode,description) VALUES ('$kee','$kee');\n";
}
close $codes_file;

foreach my $sub (split /,/,$tally_fields) {
   print "\nTally for $sub:\n";
   foreach my $kee (sort keys %{ $tally{$sub} }) {
      print $kee.':  '.$tally{$sub}{$kee}."\n";
   }
}

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int($time / 60);
my $seconds  = $time - ($minutes * 60);
my $hours    = int($minutes / 60);
$minutes    -= ($hours * 60);

printf "Finished in %dh:%dm:%ds.\n",$hours,$minutes,$seconds;

exit;
