#!/usr/bin/perl

# possible modules to use
use Getopt::Long;
use C4::Context;

# Database handle
my $dbh = C4::Context->dbh;
my $sth_input = $dbh->prepare("SELECT id, savedsql FROM saved_sql WHERE savedsql
 like '%duedate%' or savedsql like '% items.itemtype%'");
my $sth_update = $dbh->prepare("UPDATE saved_sql SET savedsql = ? WHERE id = ?")
;

# Benchmarking variables
my $startime = time();
my $goodcount = 0;
my $badcount = 0;
my $totalcount = 0;

# Options
my @input;
my $testmode;
my $verbose;
my $infile;
my $outfile;
my $delimiter = ',';

GetOptions(
  't'   => \$testmode,
  'f|file:s' => \$infile,
  'o|output:s' => \$outfile,
  'd|delimiter:s' => \$delimiter,
  'v' => \$verbose
);

# take in a textual delimiter and change to symbol
if ($delimiter eq 'pipe') {
   $delimiter = '|';
} elsif ($delimiter eq 'semicolon') {
   $delimiter = ';';
} elsif ($delimiter eq 'colon') {
   $delimiter = ':';
} elsif ($delimiter eq 'tab') {
   $delimiter = "\t";
} elsif ($delimiter eq 'space') {
   $delimiter = ' ';
}

# get either database or file input
if (defined $infile) {
   open(IN, $infile) || die ("Cannot open input file");
   my @input = <IN>;
} else {
   $sth_input->execute();
}

if (defined $outfile) {
   open (OUT, ">$outfile") || die ("Cannot open output file");
} else {
   open(OUT, ">&STDOUT") || die ("Couldn't duplicate STDOUT: $!");
}

print "Opening $infile, delimiting with '$delimiter'\n" if (defined $verbose);

# fetch info from IN file
while (my $input = $sth_input->fetchrow_hashref){
  s/[\r\n]*$//;
  my $id = $input->{id};
  my $sql = $input->{savedsql};
  if (defined $testmode) {
    print OUT "$id: old SQL = $sql\n------\n";
  }

  $sql =~ s/duedate/date_due/g;
  $sql =~ s/items\.itemtype/items\.itype/g;

  $sth_update->execute($sql, $id) unless (defined $testmode);

  $totalcount++;

  # report on progress
  if (defined $testmode) {
    print OUT "$id: new SQL = $sql\n\n";
  }
}

# Benchmarking
my $endtime = time();
my $time = $endtime-$startime;
my $accuracy = 0;
unless ($totalcount == 0) {$accuracy = $goodcount / $totalcount;}
my $averagetime = 0;
unless ($time == 0) {$averagetime = $totalcount / $time;}
print "Good: $goodcount, Bad: $badcount (of $totalcount) in $time seconds\n";
printf "Accuracy: $%.2f\%  Average time per record: $%.6f seconds\n", $accuracy,
 $averagetime if (defined $verbose);


sub open_configfile {
    my $filename = shift;
    my %return_hash;
    open(CONFIG, $filename) || die "Cannot open $filename";
    while (<CONFIG>){
      if (m/^\s*\#/) {next;}
      chomp();
      ($constant, $value) = split(/,/);
      $return_hash{$constant} = $value;
    }
    close CONFIG;
    return %return_hash;
}

