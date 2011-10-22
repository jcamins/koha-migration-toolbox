#!/usr/bin/perl
#---------------------------------
# Copyright 2010 ByWater Solutions
#
#---------------------------------
#
# This script will cleverly create new EBOOK items for biblios that do not have one.
#
# -D Ruth Bavousett
#
#---------------------------------

use strict;
use warnings;
use C4::Context;
use C4::Items;

open INFL,"<ill_barcodes.txt";

while (my $barcode = readline(INFL)){
    chomp $barcode;
    C4::Items::AddItem({ barcode => $barcode,
                         itype          => "ILL",
                         homebranch     => "DE",
                         holdingbranch  => "DE",
                        },56108);
}

