#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;
use Date::Calc qw(Add_Delta_Days);
use C4::Context;
use C4::Items;
use C4::Members;
use C4::Accounts;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $doo_eet_2 = 0;
my $i       = 0;
my $written = 0;
my $problem = 0;

my $input_filename      = $NULL_STRING;
my $borrower_map_filename = $NULL_STRING;
my %borrower_map;
my %biblio_map;

GetOptions(
    'in=s'               => \$input_filename,
    'borrower_map=s'     => \$borrower_map_filename,
    'debug'              => \$debug,
    'update'             => \$doo_eet,
    'update2'            => \$doo_eet_2,
);

for my $var ($input_filename, $borrower_map_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

Readonly my $FIELD_SEP    => chr(254);
Readonly my $SUBFIELD_SEP => chr(253);
Readonly my $TAG_SEP      => chr(252);
my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("INSERT INTO accountlines (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding, itemnumber)
        VALUES (?, ?, ?, ?,?, ?,?,?)");
my $sth_noitem = $dbh->prepare("INSERT INTO accountlines (borrowernumber, accountno, date, amount, description, accounttype, amountoutstanding)
        VALUES (?, ?, ?, ?, ?,?,?)");
my %message_map = ( '30' => 'BILL',
                    '31' => 'BILL',
                    '32' => 'BILL',
                    '33' => 'BILL',
                    '36' => 'BILL',
                    '40' => 'BILL',
                    '41' => 'BILL',
                    '42' => 'BILL',
                    '43' => 'BILL',
                    '46' => 'BILL',
                    '48' => 'BILL',
                    '49' => 'BILL',
                    '50' => 'BILL',
                    '51' => 'BILL',
                    '52' => 'BILL',
                    '53' => 'BILL',
                    '56' => 'BILL',
                    '60' => 'NOTE',
                    '61' => 'NOTE',
                    '93' => 'BILL',
                  );
my %reason_map  = ( '30' => 'F',
                    '31' => 'L',
                    '32' => 'M',
                    '33' => 'M',
                    '36' => 'M',
                    '49' => 'M',
                    '93' => 'M',
                  );
my %description_map  = ( '30' => 'Overdue Fine',
                         '31' => 'Lost Item Charges',
                         '32' => 'Damage Charges',
                         '33' => 'Misc Fees',
                         '36' => 'Card Fee',
                         '49' => 'Overpayment Credit',
                         '93' => 'Unpaid Bill',
                  );


if ($borrower_map_filename){
   my $csv = Text::CSV_XS->new();
   open my $map_file,'<',$borrower_map_filename;
   while (my $row = $csv->getline($map_file)){
      my @data = @$row;
      if ($data[0] ne $NULL_STRING) {
         $borrower_map{$data[0]} = $data[1];
      }
   }
   close $map_file;
}

my $notes_added = 0;
my $fines_added = 0;

open my $input_file,'<',$input_filename;
BORROWER:
while (my $line = readline($input_file)){
   #last BORROWER if ($debug and $i>100);
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   #$debug and print "\n$i: ";
   
   chomp $line;
   $line =~ s///g;
   my @columns = split /$FIELD_SEP/,$line;
   my $borrower = $borrower_map{$columns[0]};
   if (!$borrower) {
      print "Borrower $columns[0] not found.\n";
      $problem++;
      next BORROWER;
   }
   my $this_borrower = GetMember(borrowernumber => $borrower);
   if (!$this_borrower) {
      print "Borrower $columns[0] not found.\n";
      $problem++;
      next BORROWER;
   }
   
   for my $m (6..18) {
      if ($columns[$m] =~ /$SUBFIELD_SEP$/) {
         $columns[$m] .= ' ';
      }
   }
 
   my @related_items        = split /$SUBFIELD_SEP/,$columns[6];
   my @trans_messagecodeses = split /$SUBFIELD_SEP/,$columns[14];
   my @trans_dateses;
   if (exists $columns[15]) {
      @trans_dateses        = split /$SUBFIELD_SEP/,$columns[15];
   }
   my @trans_amountses      = split /$SUBFIELD_SEP/,$columns[18];
   my @trans_noteses;
   if (exists $columns[19]) {
      @trans_noteses        = split /$SUBFIELD_SEP/,$columns[19];
   }

TRANSACTION:
   for my $j (0..scalar(@trans_messagecodeses)-1) {
      my $thisitem_barcode = $related_items[$j] || $NULL_STRING;
      my $thisitem_itemnumber = GetItemnumberFromBarcode($thisitem_barcode);
      my $original_fine = 0;
      my $outstanding   = 0;
      my $reason        = $NULL_STRING;
      my $bill_date     = $NULL_STRING;
      my $description   = $NULL_STRING;

      my @trans_messagecodes = split /$TAG_SEP/,$trans_messagecodeses[$j];
      my @trans_dates;
      if (exists $trans_dateses[$j]) {
         @trans_dates        = split /$TAG_SEP/,$trans_dateses[$j];
      }
      my @trans_amounts      = split /$TAG_SEP/,$trans_amountses[$j];
      my @trans_notes;
      if (exists $trans_noteses[$j]) {
         @trans_notes        = split /$TAG_SEP/,$trans_noteses[$j];
      }

MESSAGE:
      for my $k (0..scalar(@trans_messagecodes)-1) {
         my $this_message = $trans_messagecodes[$k];
         next MESSAGE if (!exists $message_map{$this_message});
         if ($message_map{$this_message} eq 'NOTE') {
            my $this_date = _process_date($trans_dates[$k]);
            my $this_note = $trans_notes[$k] || $NULL_STRING;
            my $old_note = $this_borrower->{borrowernotes} || $NULL_STRING;
            my $new_note = "$old_note | $this_date: $this_note ($thisitem_barcode)";
            $new_note =~ s/\(\)//;
            $new_note =~ s/^ \| //;
            $debug and print "Borrower $this_borrower->{cardnumber} OLD NOTE: $this_borrower->{borrowernotes} NEW: $new_note\n";
            if ($doo_eet) {
               ModMember(borrowernumber => $borrower,
                         borrowernotes  => $new_note,
                        );
            }
            $notes_added++;
            next MESSAGE;
         }
         if ($message_map{$this_message} eq 'BILL') {
            if (!$original_fine) {
               $original_fine = $trans_amounts[$k];
               $outstanding   = $trans_amounts[$k];
               $reason        = $reason_map{$this_message};
               $description   = $description_map{$this_message};
               $bill_date     = _process_date($trans_dates[$k]);
            }
            else {
               $outstanding += $trans_amounts[$k];
               if ($trans_amounts[$k] > 0) {
                  $original_fine += $trans_amounts[$k];
               }
            }
         }
      }
      if ($original_fine) {
         $debug and print "Borrower $this_borrower->{cardnumber} Date: $bill_date Reason: $reason Desc: $description Orig: $original_fine  Out: $outstanding\n";
         $original_fine /= 100;
         $outstanding /= 100;
         if ($doo_eet_2) {
            my $account_number = getnextacctno($borrower);
            if ($thisitem_itemnumber) {
               $sth->execute($borrower,$account_number,$bill_date,$original_fine,$description,$reason,$outstanding,$thisitem_itemnumber);
            }
            else {
               $sth_noitem->execute($borrower,$account_number,$bill_date,$original_fine,$description,$reason,$outstanding);
            }
         }
         $fines_added++;
      }
   }
}

close $input_file;

print "\n\n$i borrowers read.\n$notes_added notes added to borrowers.\n$fines_added fine records added.\n$problem problems encountered.\n";

exit;

sub _process_date {
   my $datein = shift;
   return q{} if !$datein;
   return q{} if $datein eq q{};
   return q{} if $datein < 0;
   my ($year,$month,$day) = Add_Delta_Days(1967,12,31,$datein);
   return sprintf "%4d-%02d-%02d",$year,$month,$day;
}
