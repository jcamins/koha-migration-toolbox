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
use Digest::MD5 qw(md5_base64);
use C4::Context;
use C4::Members;

my $dbh = C4::Context->dbh();
my $sth = $dbh->prepare("SELECT borrowernumber,cardnumber,userid FROM borrowers WHERE categorycode <> 'ST' and cardnumber <> userid");
$sth->execute();
while (my $rec = $sth->fetchrow_hashref()){
   if ($rec->{'userid'} ne $rec->{'cardnumber'}){
      my $tempword = substr($rec->{'cardnumber'},length($rec->{'cardnumber'})-4,4);
      C4::Members::ModMember( borrowernumber => $rec->{'borrowernumber'},
                              userid => $rec->{'cardnumber'},
                              password => $tempword);
      warn $rec->{'borrowernumber'};
   }
}

