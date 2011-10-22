#!/usr/bin/perl

# Version 0.7
#
# Copyright 2009 Ian Walls
#
# This script is a supplemental tool to Koha to bulk load borrower attributes
# from a file 
#
# This is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This script is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# Koha; if not, write to the Free Software Foundation, Inc., 59 Temple Place,
# Suite 330, Boston, MA  02111-1307 USA




# Modules to use for this script
use C4::Context;
use C4::Members;
use Getopt::Long;

my ($inputfile, $help, $test);
my $type = 'borrowernumber';

GetOptions(
  'f|file:s'	=> \$inputfile,
  'h|help'	=> \$help,
  't|test'	=> \$test,
  'id:s'    => \$type
);


if (defined $help || !defined($inputfile)) {
    print <<EOF
Small script to import patron attributes into Koha from a flat file.  Unwanted 
patron attribute values must be deleted from the borrower_attributes table prior 
to running this script in order to avoid duplicates.

Parameters:
  f|file  /path/to/file: the file to import
  h|help  this screen 
  t|test  test mode; does not commit change to the db
  id      specify the unique id used for the patron (borrownumber is default)

This script expects a CSV file, with the unique identifer for the patron as the 
first value per row, and attribute:value (separated by :) pairs for each
subsequent value. You may insert as many attributes per patron as your Koha 
setup is configured to allow (see Koha manual to define patron attribute types).

Specify "-id cardnumber" or "-id userid" to use cardnumber or userid to link to
the patron's record (instead of borrowernumber).

Example of a row from the CSV file:

35,ATTR1:something,ATTR2:something else
  
EOF
;#'
exit;
}


# open input argument file
open(IN, $inputfile) || die "Can't open input file...\n";

my $dbh = C4::Context->dbh;
my $sth = $dbh->prepare(
  "INSERT INTO borrower_attributes (borrowernumber, code, attribute) 
   VALUES (?,?,?)"
);

while (<IN>){
  chomp();
  my @borrowerattributes = split(/,/);
  my $id = shift(@borrowerattributes);
  my $borrower = GetMember($id, $type);
  my $borrowernumber = $borrower->{'borrowernumber'};
  foreach $borrowerattribute (@borrowerattributes) {
    my @bits = split(/:/, $borrowerattribute);
    my $code = $bits[0];
    my $attribute = $bits[1];
    if ($borrowernumber && $code && $attribute){
      if (defined $test) {
    	  print "OK - id: \"$id\"  borrowernumber: \"$borrowernumber\"  attribute: \"$code\"  value: \"$attribute\" \n";
    	} else {  
      	$sth->execute($borrowernumber, $code, $attribute);
      }
    } else {
	      print "ERROR for id $id: borrowernumber, attribute or value not defined\n  Borrowernumber: \"$borrowernumber\"  Attribute: \"$code\"  Value: \"$attribute\" \n";
    }
  }
}

