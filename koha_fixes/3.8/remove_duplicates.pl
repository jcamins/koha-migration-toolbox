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
use Data::Dumper;

my $dbh = C4::Context->dbh;

my $query = "
    SELECT * FROM accountlines     
    WHERE ( accounttype =  'FU' OR accounttype =  'F' )
    AND description like '%23:59%'
    ORDER BY borrowernumber, itemnumber, accountno, description
";
my $sth = $dbh->prepare($query);
$sth->execute();
my $results = $sth->fetchall_arrayref( {} );

$query =
"SELECT * FROM accountlines WHERE description LIKE ? AND description NOT LIKE ?";
$sth = $dbh->prepare($query);

my @fines;
foreach my $keeper (@$results) {

    warn "WORKING ON KEEPER: " . Data::Dumper::Dumper( $keeper );
    my ($description_to_match) = split( / 23:59/, $keeper->{'description'} );
    $description_to_match .= '%';

    warn "DESCRIPTION TO MATCH: " . $description_to_match;

    $sth->execute( $description_to_match, $keeper->{'description'} );

    my $has_changed = 0;

    while ( my $f = $sth->fetchrow_hashref() ) {

        warn "DELETING: " . Data::Dumper::Dumper( $f );

        if ( $f->{'amountoutstanding'} < $keeper->{'amountoutstanding'} ) {
            $keeper->{'amountoutstanding'} = $f->{'amountoutstanding'};
            $has_changed = 1;
        }

        my $sql =
            "DELETE FROM accountlines WHERE borrowernumber = ? AND accountno = ? AND itemnumber = ? AND date = ? AND description = ? LIMIT 1";
        $dbh->do( $sql, undef, $f->{'borrowernumber'},
            $f->{'accountno'}, $f->{'itemnumber'}, $f->{'date'},
            $f->{'description'} );
    }

    if ($has_changed) {
        my $sql =
            "UPDATE accountlines SET amountoutstanding = ? WHERE borrowernumber = ? AND accountno = ? AND itemnumber = ? AND date = ? AND description = ? LIMIT 1";
        $dbh->do(
            $sql,                           undef,
            $keeper->{'amountoutstanding'}, $keeper->{'borrowernumber'},
            $keeper->{'accountno'},         $keeper->{'itemnumber'},
            $keeper->{'date'},              $keeper->{'description'}
        );
    }
}

exit;

