#!/usr/bin/perl

# Copyright 2011 Tomas Cohen Arazi @ Universidad Nacional de Cordoba
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use strict;
use warnings;

use C4::Context;
use C4::Biblio;
use Getopt::Long;

my ($wherestring,$debug);
my $result = GetOptions(
    'where:s'      => \$wherestring,
    'd'    => \$debug
);

my $dbh       = C4::Context->dbh;
my $encoding  = C4::Context->preference("marcflavour");
my $querysth  =  qq{SELECT biblionumber from biblioitems };
$querysth    .= " WHERE $wherestring " if ($wherestring);
my $query     = $dbh->prepare($querysth);
$query->execute;

while (my $biblionumber = $query->fetchrow){

    print "\r$biblionumber" if $debug;

    my $record = MyGetMarcBiblio($biblionumber);
   
    if (defined $record) {
      # Generate USMARC record
      eval {
        my $usmarc = $record->as_usmarc();
      };

      if ($@){
        warn "###\nError creating MARC record for biblionumber: $biblionumber\n";
        warn "$@###\n\n";
       }

      # Generate MARCXML record
      eval {
        my $marcxml = $record->as_xml_record($encoding);
      };

      if ($@){
        warn "###\nError creating MARCXML record for biblionumber: $biblionumber\n";
        warn "$@###\n\n";
      }
    }
    else {
        warn "###\nError retreiving record for biblionumber: $biblionumber\n###\n";
    }
}

sub MyGetMarcBiblio {
    my $biblionumber = shift;
    my $dbh = C4::Context->dbh;
    my $sth = $dbh->prepare("SELECT marcxml FROM biblioitems WHERE biblionumber=? ");
    $sth->execute($biblionumber);
    my $row = $sth->fetchrow_hashref;
    my $marcxml = C4::Biblio::StripNonXmlChars($row->{'marcxml'});
    MARC::File::XML->default_record_format(C4::Context->preference('marcflavour'));
    my $record = MARC::Record->new();
    if ($marcxml) {
        $record = eval {MARC::Record::new_from_xml( $marcxml, "utf8", C4::Context->preference('marcflavour'))};
        if ($@) {warn " problem with :$biblionumber : $@ \n$marcxml";}
        return $record;
    } else {
        return undef;
    }
}

