#!/usr/bin/perl

use strict;
use warnings;

# CPAN modules
use DBI;
use Getopt::Long;

# Koha modules
use C4::Context;
use C4::Installer;
use C4::Dates;

use MARC::Record;
use MARC::File::XML ( BinaryEncoding => 'utf8' );

my $dbh = C4::Context->dbh;

my $pref = C4::Context->preference('dateformat');
my ( $date_format, $date_regex );

if ( $pref =~ /^iso/ ) {
    $date_format = '____-__-__';
}
elsif ( $pref =~ /^metric/ ) {
    $date_format = '__/__/____';
}
elsif ( $pref =~ /^us/ ) {
    $date_format = '__/__/____';
}
else {
    $date_format = '____-__-__';
}

my $sql =
"SELECT * FROM accountlines WHERE description LIKE '%$date_format%' AND description NOT LIKE '%$date_format __:__%' AND ( accounttype = 'FU' OR accounttype = 'F' )";
my $sth = $dbh->prepare($sql);
$sth->execute();
my $i=0;

while ( my $row = $sth->fetchrow_hashref() ) {
    print '.';
    print "\r$i" unless ($i % 100);
    $i++;
    #use Data::Dumper; print Dumper($row);
    my $old_description = $row->{'description'};

    my ( $year, $month, $day );
    my $date;

    if ( $pref =~ /^iso/ ) {
        ( $year, $month, $day ) = $old_description =~ /(\d+)-(\d+)-(\d+)/;
        $date = "$year-$month-$day";
    }
    elsif ( $pref =~ /^metric/ ) {
        ( $day, $month, $year ) = $old_description =~ /(\d+)\/(\d+)\/(\d+)/;
        $date = "$day/$month/$year";
    }
    elsif ( $pref =~ /^us/ ) {
        ( $month, $day, $year ) = $old_description =~ /(\d+)\/(\d+)\/(\d+)/;
        $date = "$month/$day/$year";
    }
    else {    ## default to iso
        ( $year, $month, $day ) = $old_description =~ /(\d+)-(\d+)-(\d+)/;
        $date = "$year-$month-$day";
    }

    my $datetime = "$date 23:59";

    my $new_description = $old_description;
    $new_description =~ s/$date/$datetime/g;

    my $err = $dbh->do( "UPDATE accountlines SET description = ? WHERE borrowernumber = ? AND accountno= ?",
        undef, $new_description, $row->{borrowernumber},$row->{accountno});
    if ($err != 1) {
       use Data::Dumper; print Dumper($row);
       print "NEW: $new_description\nERR: $err\n";
       #last;
    }
}

exit;

