#!/usr/bin/perl
#
# Copyright 2010 Catalyst IT Ltd.
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

# Written by Robin Sheat <robin@catalyst.net.nz>
# Manpage formatting tweaks by Lars Wirzenius <lars@catalyst.net.nz>, 2010

use utf8;

=head1 NAME

csvtomarc.pl - takes a CSV file and exports it as MARC

=head1 SYNOPSIS

B<csvtomarc.pl> 
B<--input>=I<file> 
[B<--preview>=I<numlines>]
[B<--output>=I<file>] 
B<--mapping>=I<column>=I<field> ...
[B<--nostrict>] 
[B<--skipkoha>]
[B<--kohaconf>=I<file>] 
[B<--kohalibs>=I<path>]
[B<--format>=I<MARC format>]
[B<--loosequotes>]
[B<--split>=I<items>]
[B<--debug>]
[B<--help>]
[B<--man>]

=head1 DESCRIPTION

B<csvtomarc.pl> converts a comma-separated values file (CSV) to a MARC21 file,
using a mapping provided either on the command line or in a config file.

=head2 Mappings

Mappings are key to the data transformation. At the simplest level, they
link CSV columns to Koha fields, however they are required to do a bit more
than that also.

To map the 'book title' column to the Koha 'title' field, use 
B<-m 'book title=title'>. To make it compulsory, append an '!': 
B<-m 'book title=title!'>. This will mean an error will be raised and
the process will be stopped if that field has no value. To make the field 
optional, append a '?': B<-m 'book title=title?'>. This means that if the
field has no value, it will be ignored. See the B<--nostrict> option
for more information on the subtleties of this.

If you don't want a column to be checked when determining if a row is blank
(say, the date field is always filled in, no matter what), put a '*' at the
end of its mapping, e.g. B<date=marc:260_c?*>.

To force a field to be repeated, rather than a subfield as is usually the
default, append a '%'. To force a field to B<never> be repeated, append
a '-'.

=head3 Destination Functions

Sometimes there may not be a simple Koha field for the record you want to
write, in this case, there are functions you can use:

=over

=item marc

The B<marc> function allows a literal MARC field value to be supplied, for 
example: B<-m myfield=marc:123_m>, where '123' is the MARC tag and 'm' is
the subfield.

=item multimarc

Similar to B<marc>, thhe B<multimarc> function allows a set of marc field
values to be supplied. If the input is a list of values (say, from 
B<func:split>) then each value from the split will be placed into each
successive MARC value, until either the fields or the values run out. For
example: B<-m func:split:;:SERIES=multimarc:490_a:490_v>. If the last value
is B<...>, then the last MARC field will be repeated until the source values
run out. E.g. B<-m func:split:;:AUTHOR=multimarc:100_a:700_a:...> If a field
is simply B<_>, then the value in that position is discarded.

If 'r' is provided as the first marc specification, then it is a flag that
indicates that subfields should be repeated, not tags.

=item special:isbn

This will validate the value, and if it's an ISBN it will put it in 
biblioitems.isbn, if it's an ISSN, it'll go in biblioitems.issn. If
it's not valid, it will either warn or abort, depending on the 
optional/required setting for the field, and if B<--nostrict> is specified.

=item special:count

This won't get written to any MARC record, however it will be used to
duplicate the 952 tag a number of times, which will allow Koha to see
it as a number of items. A blank or unparsable field will count as '1'.

=item special:title

This cleans up titles, and seperates them in to 245$a, $b and $c based on ':'
and '/'. (Note: MARC21 specific.)

=item special:titleparts

This takes multiple values and places them into 245$a, 245$b, and 245$c as
appropriate. It will also put the correct ':' and '/' punctuation at the end
of the fields if required. It only looks at its own input to determine what is
required, so if (say) the 245$c value is coming from some other field, this
won't help. E.g. B<-m 'func:split:|:title=special:titleparts'>

=item skipif:regex

If the field matches the regex given here, this record will be ignored.
For example, B<-m classification=skipif:^INTERLOAN:> will skip any
record that has the B<classification> column start with 'INTERLOAN'.

=item special:language

This takes a MARC field, as in B<marc>, and puts the supplied value in there,
after attempting to convert it to a MARC language code. If the MARC code
matching the language can't be found, a warning will be issued and the 
existing value will be put in. For example,
B<-m language=special:language:024_a>. See also the B<--lang> option.

=item append

This allows you send multiple columns to one, non-repeating, field. All the
values sent to it will be seperated with a couple of linefeeds and put
together. The column may also be of the form 'marc:123_x' to specify a MARC
field. For example B<-m notes=append:notes -m prefix:Description: 
:descr=append:notes> will join these together in the same notes field. Note
that there is no concept of order, it'll effectively be random.

=back

=head3 Source Functions

Source functions can be used to put computed values into the record.
When using a source function, you must always prefix its name with 'func:'
to prevent confusion with spreadsheet columns.
Available functions are:

=over

=item today

B<today> will insert the current date.

=item split

B<split> takes a character and a CSV column name, and it will split 
the column value on that, allowing a different record
to be created for each part of the input. For example:
B<-m 'func:split:;:subject=marc:650_a?'> will split the 'subject' column
on a semicolon, and it will be put into marc:650_a (as a repeated entry.)

=item splitcount

B<splitcount> is syntactically the same as B<split>, however instead of
returning a list of values, it returns the numerical value specifying the
number of items that would be returned by B<split>. For example:
B<-m 'func:splitcount:;:accession=special:count'> will create a seperate
item for each element in the semicolon-seperated list in the accession 
column.

=item prefix

B<prefix> adds a prefix to the field before it passes it on. For example:
B<-m 'func:prefix:Extra Notes: :extranotes=append:notes'>. Note that the
last colon is used for determining the source column, so having colons in the
text is OK.

=item text

B<text> adds the specified text into the field, not pulling any data from
the CSV.

=item combine

B<combine> allows multiple columns to be mixed together in different ways.  It
supports the operators B<upto>, B<after>, B<append>, and B<text>. B<upto> takes the
value from the column, up to the supplied string, B<after> takes everything
after the string, and B<append> appends a string followed by the value from a
column. For example, B<-m func:combine:upto:;:Source:append: ; :Year> will take
the Source column up to ';', append ' ; ' to it, and include the value from the
Year column. B<text> adds a single argument as plain text to the string.

=item ifmatch

B<ifmatch> allows a list of C<regex:value:regex:value:...>, and the first regex
that the input matches has the value that follows it returned. The final thing
in the list should be the column name. If the first entry in the list is the
string 'anchor', then the regexes are anchored with ^ and $. You probably want
this.

=item item

B<item> is special, in that it can prefix any source description, whether thats
a column name or a function. It says that this column should be taken from the
items table, rather than the biblios table (which is the default.) For
example: B<-m item:barcode=barcode> says that the 'barcode' column from the
items table should be used to populate the item record. See
B<--items> and B<--itemlink> for information that goes with this.

=item titlecase

B<titlecase> converts the text in the specified to title case (i.e. the first
letter of every word capitalized).

=back

To use a function, use a mapping such as B<-m func:today=dateaccessioned>.

=head1 OPTIONS

=over

=item B<-i>, B<--input>=I<file>

The input CSV file. Required.

=item B<-o>, B<--output>=I<file> 

The output MARC XML file. Required unless you use B<--preview>. If the
destination is B<->, the output will go to the standard output.

=item B<-m>, B<--mapping>=I<mapping>

Note: while the basics are here, there are more details in the "Mappings"
section above.

This maps a CSV column to the koha field name. This field name will be looked
up to get the MARC tag and subfield that corresponds to it. Mappings should
be expressed in the form: B<column=field>, for example to map the CSV column
'book title' to the koha field 'title', use B<--mapping="book title=title">.

You can append a '?' on to the end of the mapping to signify that this item is
optional, for example: B<--mapping="note=notes?">. Optional fields are
happily set to blank if the CSV column is empty or unparsable.

Similarly, appending '!' makes it a compulsory field. If B<strict> is enabled
then this makes no difference, if B<strict> is disabled, then it will
cause the record to be skipped (and a warning will be emitted.)

Using interrobang, '‽', will do nothing useful.

It is expected that there will be a lot of B<--mapping> entries on the
command line.

=item B<-d>, B<--dateformat>=I<format>

(Not yet implemented)

=item B<-t>, B<--items>=I<file>

This specifies a CSV file containing a row for each item. These are linked
up using the parameter given to B<--itemlink>.

=item B<--itemlink>=I<link description> 

This describes how to link the items table and the biblios table. It has the
name of a column in the biblios table that will be one-to-many matched to
a column in the items table. For example, B<--itemlink ID=ID> means that
for each row in the biblios table, the value in column ID will be looked up
in the ID column in the items table, and all matching results will become
items.

=item B<--nostrict>

If strict is on (default), then any field that can't be parsed will cause
an abort of the whole process. If it's off, that field will be left blank.
The optional and compulsory markers in the mapping are influenced by the
setting of this also.

=item B<--quiet>

Do not print a summary at the end of processing.

=item B<-p>, B<--preview>=I<numlines>

If you haven't specified an output file, this will dump the first I<numlines> 
lines from the CSV to stdout in a human-readable fashion. It's useful for 
checking you've got the right mapping.

If you have specified an output file, then it will do everything it normally 
would do, but only for I<numlines> records.

=item B<--kohaconf>=I<file>

This is the path to your Koha configuration XML file, usually called
B<koha-conf.xml>. If this is not supplied, The B<KOHA_CONF> environment
variable is checked.

=item B<--kohalibs>=I<path>

If Koha has been installed in such a way that the B<C4> packages aren't in 
your regular Perl libraries search path, this will let you specify the 
location. Just point it to the base directory that you have Koha installed 
or checked out into. Note that this program makes some effort to guess where
things are, so it may be you don't need to provide this.

This is similar to setting B<perl -I>, or the B<PERL5LIB> environment
variable.

=item B<--skipkoha>

Do not use any C4 functions. With this set, the ISBN and ISSN destination
functions will not work, nor will using Koha database names for destinations.

=item B<-f>, B<--format>=I<MARC format>

This is the file format that will be output. Valid options are B<usmarc>
and B<marcxml>. B<marcxml> is the default.

=item B<-l>, B<--loosequotes>

Allows parsing of badly formed CSV files that contain un-escaped quotes in
the middle of fields. Should be avoided normally, but some legacy products
(e.g. Liberty) seem to export like this due to issues with standards.

An indication you should use this is if you see:

   An error occurred processing file.csv: EIQ - QUO character not allowed

=item B<--tab>

The source files are tab-seperated rather than comma-seperated. This is a
shortcut for B<--fieldsep '\t'>.

=item B<--fieldsep>

Specifies a custom field separator character. Only one of B<--fieldsep> and
B<--tab> can be specified at a time. '\t' may be used to indicate tab.

=item B<--itemfieldsep>

Specifies a custom field separator character for the items file. If this is
not supplied, it will be assumed to be the same as for the biblio file. It
may be '\t' to indicate tab.

=item B<--quotechar>

Specifies a custom quote character. Defaults to double quote.

=item B<--leader>

Specifies the leader to use for the MARC records. Defaults to
'00000pam\\2200000ua\4500'

=item B<--skipnoitems>

If this is set, then any biblios that have no items will not be included in
the resulting MARC.

=item B<--libertymarc>

This says that your biblio file contains MARC records exported from Liberty 3.
The file will have a large number of columns (up to 999) that are formed like
'Txxx', the fields will have the MARC subfields in there in a special,
hopefully decodable, format. This will decode them and put them in the output.
Any field that is explicitly defined will not be included in this process.

=item B<--dedupfields>

Don't allow any fields with the exact same contents. Usually only required when
using B<--reduce> on a non-sparse file.

=item B<--unuseditemsreport>

This produces a file that lists the IDs of all the items that do not get
referenced by a biblio record.

=item B<-s>, B<--split>

This specifies the number of items that will be attached to a single biblio
record. If there are more than this, the biblio record will be cloned. This
helps prevent MARC records getting too large.

=item B<--lang>

This specifies the MARC language mapping file to use. This file can be found
at B<http://www.loc.gov/standards/codelists/languages.xml>.

=item B<--reduce>=I<column>

Use the specified comma-separated columns as a matching key to combine multiple
rows in the CSV into a single MARC record.

=item B<--requirereduce>

If set, at least one of the fields being used for record reduction must have
data or the line will be skipped.

=item B<--reduceblank>

If set, all records lacking any data in the reduce key fields will be reduced
to one record. No effect if B<--requirereduce> is set.

=item B<--allowblank>

If set, process records even if they are considered "blank." This is needed when
all input fields are handled with source functions.

=item B<-v>, B<--debug>

Each B<--debug> or B<-v> item will increase the amount of debug information 
displayed while running. Be aware that this may hide legitimate warnings.

=item B<--help>

A basic synopsis of the program.

=item B<--man>

All the details on the program.

=back

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;
use Text::CSV_XS;
use MARC::Record;
use MARC::File::XML (BinaryEncoding => 'utf8');
use Data::Dumper;
use Business::ISBN;
use Business::ISSN;
use Carp;
use XML::LibXML;
use Encoding::FixLatin qw/ fix_latin /;

# Note: all C4-related includes should go in a bit further down, as it
# wants to find the location they're in first.

my ($input_file, $output_file, $items_file);
my (@mapping_cli, $date_format, $preview, $config, $help, $man, $loosequotes);
my ($item_link, $item_split, $lang_file, $tab_sep, $field_sep, $item_field_sep, $quote_char);
my ($unused_items_report, $liberty_marc, $skip_no_items, $allow_blank);
my ($reduce, @reductions, $require_reduce, $reduce_blank);
my $strict = 1; # strict by default
my $quiet;
my %records;
my $debug_level = 0;
my $koha_conf = $ENV{KOHA_CONF};
my $koha_libs;
my $leader = '00000pam  2200000ua 4500';
my $marc_format = 'marcxml';
my $skip_koha;
my $dedup_fields;
GetOptions(
    'input|i=s'         => \$input_file,
    'output|o=s'        => \$output_file,
    'mapping|m=s'       => \@mapping_cli,
    'dateformat|d=s'    => \$date_format,
    'strict!'            => \$strict,
    'preview|p=i'       => \$preview,
    'configfile|c'      => \$config,
    'kohaconf=s'        => \$koha_conf,
    'kohalibs=s'        => \$koha_libs,
    'debug|v+'          => \$debug_level,
    'format|f=s'        => \$marc_format,
    'loosequotes|l'     => \$loosequotes,
    'tab'               => \$tab_sep,
    'fieldsep=s'        => \$field_sep,
    'itemfieldsep=s'    => \$item_field_sep,
    'quotechar=s'      => \$quote_char,
    'items|t=s'         => \$items_file,
    'itemlink=s'        => \$item_link,
    'leader=s'          => \$leader,
    'reduce=s'          => \$reduce,
    'skipkoha'          => \$skip_koha,
    'skipnoitems'       => \$skip_no_items,
    'allowblank'        => \$allow_blank,
    'split|s=i'         => \$item_split,
    'unuseditemsreport=s'   => \$unused_items_report,
    'libertymarc'       => \$liberty_marc,
    'dedupfields'       => \$dedup_fields,
    'requirereduce'     => \$require_reduce,
    'reduceblank'       => \$reduce_blank,
    'lang=s'            => \$lang_file,
    'help|h'            => \$help,
    'man'               => \$man,
    'quiet|q'           => \$quiet
) or pod2usage(2);

$marc_format = lc($marc_format);

pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

pod2usage("At least one mapping must be supplied.\n") if (!@mapping_cli && !$liberty_marc);
pod2usage("An input file must be supplied.\n") if (!$input_file);
pod2usage("An output file must be supplied.\n") if (!$output_file && !$preview);
pod2usage("Valid MARC formats are 'usmarc' and 'marcxml'.\n") if ($marc_format ne 'usmarc' && $marc_format ne 'marcxml');
pod2usage("An itemlink needs to be supplied if you want an items file.\n") if ($items_file && !$item_link);
pod2usage("An itemlink is useless without an items file.\n") if ($item_link && !$items_file);
pod2usage("Only one of --tab and --fieldsep can be given at a time.\n") if ($field_sep && $tab_sep);
pod2usage("The argument given to --fieldsep must be a single character.\n") if ($field_sep && $field_sep ne '\t' && length($field_sep) > 1);
pod2usage("The argument given to --quotechar must be a single character.\n") if ($quote_char && $quote_char ne '\t' && length($quote_char) > 1);
pod2usage("The argument given to --itemfieldsep must be a single character.\n") if ($item_field_sep && $item_field_sep ne '\t' && length($item_field_sep) > 1);
pod2usage("--unuseditemsreport makes no sense if there's no items file. Have you the brain worms?") if ($unused_items_report && !$items_file);

debug(1,"Debug level set to $debug_level");

# Check the provided mapping and convert it to something more useful
my @mapping;
foreach my $map (@mapping_cli) {
	my ($col, $field) = $map =~ /^(.*?)=(.*)$/;
	if (!$col || !$field) {
warn "$col     $field\n";
    	die "$map is not correctly specified\n";
    }
    my $optional = ($field =~ /\?\W*$/);
    my $required = ($field =~ /!\W*$/);
    my $ignoreforblank = ($field =~ /\*\W*$/);
    my $repeatfield = ($field =~ /%\W*$/) ? 1 : ($field =~ /-\W*$/) ? -1 : 0;
    $field =~ s/[!?%*]*$//;
    push @mapping, {
        'field'     => $field,
        'optional'  => $optional,
        'required'  => $required,
        'ignoreforblank' => $ignoreforblank,
        'column'    => $col,
        'repeatfield'   => $repeatfield,
    };
}

my %language_map = load_langs($lang_file) if ($lang_file);

@reductions = split(/,/, $reduce);
chomp @reductions;

unless ($skip_koha) {
    pod2usage("Either the KOHA_CONF environment variable, or --kohaconf must be set.\n") if (!$koha_conf);
    $ENV{KOHA_CONF} = $koha_conf;

    # Try to find our libraries.
    my ($found_path, $path_not_needed);
    if ($koha_libs && -d "$koha_libs/C4") {
        $found_path = $koha_libs;
    } elsif (-d 'C4') {
        $found_path = '.';
    } elsif (-d '../C4') {
        $found_path = '..';
    } elsif (-d '../../C4') {
        $found_path = '../..';
    } elsif ($koha_conf && -d $koha_conf.'/C4') {
        $found_path = $koha_conf;
    } else { # give up, maybe it's already in the path?
        eval 'require C4::Biblio';
        if ($@) {
            pod2usage("Unable to find the C4 modules. Use the kohalibs option\n.");
        }
    # hey, it worked! 
    }
    push @INC, $found_path;

    # ---- C4 INCLUDES GO HERE (and are 'requires') ---
    require C4::Biblio;
    require C4::Items;
}

# This defines the functions that can be called with the mapping type 'func:'
# The _column_re ones are to make it easy to grab a column name from a
# function definition, where possible, to tell which column a function
# references.
my %source_functions = (
    'today'     => sub {
        my (undef,undef,undef,$mday,$mon,$year,undef,undef,undef) = localtime(time);
        $year += 1900;
        return "$year-$mon-$mday";
    },
    'literal'   => sub {
        return shift;
    },
    'split'     => \&split_source,
    'split_column_re'   => qr/:([^:]*)$/,
    'splitcount'=> \&splitcount_source,
    'splitcount_column_re'   => qr/:([^:]*)$/,
    'splitlast' => \&splitlast_source,
    'splitlast_column_re'   => qr/:([^:]*)$/,
    'prefix'    => \&prefix_source,
    'prefix_column_re'   => qr/:([^:]*)$/,
    'text'      => \&text_source,
    'text_column_re'    => qr//,
    'ifmatch'   => \&ifmatch_source,
    'ifmatch_column_re'   => qr/:([^:]*)$/,
    'combine'   => \&combine_source,
    'titlecase' => \&titlecase_source,
    'titlecase_column_re' => qr/^(.*)$/,
);

# Convert the Koha mappings into MARC fields
#
# We need to check each of these field types to see if they're the field that
# we want, so we can just say 'title' and have it work it out.
foreach my $map (@mapping) {
    # This modifies %$map in-place
    field_to_mapping($map->{column}, $map);
}

my ($eol_char);

my ($field_sep_char, $item_field_sep_char);
if ($tab_sep || (defined($field_sep) && $field_sep eq '\t')) {
	$field_sep_char = "\t";
} elsif ($field_sep) {
    $field_sep_char = $field_sep;
} else {
	$field_sep_char = ',';
}

if ($item_field_sep && $item_field_sep eq '\t') {
	$item_field_sep_char = "\t";
} elsif ($item_field_sep) {
	$item_field_sep_char = $item_field_sep;
} else {
	$item_field_sep_char = $field_sep_char;
}

if ($quote_char && $quote_char eq '\t') {
    $quote_char = "\t";
} else {
    $quote_char ||= '"';
}

# If we've got an items file to work with, we load it up now.
my $items_data;
if ($items_file) {
	$items_data = load_items_data($items_file, $item_link, $item_field_sep_char);
}

# OK, if we're here, everything has loaded. Now to start processing the file.
my $csv = Text::CSV_XS->new({
        binary  => 1,   # binary handles funny line endings and macrons etc.
        #eol     => "\r\n",
        allow_loose_quotes => $loosequotes,
        escape_char => ( $loosequotes ? '' : '"'),
    	sep_char => $field_sep_char,
        quote_char => $quote_char,
    	auto_diag => 2,
    });
open my $csvfile, '<:encoding(UTF-8)', $input_file
    or die "Unable to open $input_file: $!\n";
# First get the header line and hashify it.
my $header_row = $csv->getline($csvfile);
debug(4, "Header row: ".join(', ', @$header_row));
my $count=0;
my %header_to_column = map { $_ => $count++ } @$header_row;

my %literal_headers;
foreach my $map (@mapping) {
    ($map->{'sourcefunc'}, $map->{'is_item_field'}, $map->{'column'},
     $map->{'realcolumn'}) =
        mapping_source($map->{'column'});
    next if (!$map->{'realcolumn'});
    $literal_headers{$map->{realcolumn}} = exists($header_to_column{$map->{realcolumn}});
}

# Now, if we need to, we add the functions to deal with liberty MARC stuff.
if ($liberty_marc) {
	foreach my $header (@$header_row) {
    	next if $literal_headers{$header};
    	if ($header =~ /^T\d\d\d$/) {
            $literal_headers{$header} = 1;
            my $map = create_liberty_map($header);
            push @mapping, $map;
        } elsif ($header eq 'HEADER') {
            $literal_headers{$header} = 1;
        	my $map = create_leader_map($header);
        	push @mapping, $map;
        }
    }
}

# And finally, we build an array of MARC records. Currently this saves them in
# memory. If you are dealing with a _huge_ CSV, you may want to do something
# about that.

my @records;
my $record_count = 0;
my ($stat_skipped, $stat_bibsadded, $stat_itemsadded, $stat_records,
    $stat_itemsskipped)=(0,0,0,0,0);

my $output_fh = open_output_file($output_file);

debug(5, 'Starting to load records');
ROW: while (my $row = $csv->getline($csvfile)) {
    $stat_records++;
    $record_count++; # we count from 1 for this
    last if ($preview && $preview < $record_count);

    debug(2, "Processing record $record_count");

    my $marc_record;
    my $reducekey = '';
    if (@reductions) {
        foreach my $reduction (@reductions) {
            if ($row->[$header_to_column{$reduction}]) {
                $reducekey .= '-' . $row->[$header_to_column{$reduction}];
            }
        }
        unless (!$require_reduce || $reducekey =~ m/[^- ]/) {
            warn "Record $record_count has no reduction key, skipping\n";
            next;
        }
    }
    if (($reducekey || $reduce_blank) && $records{$reducekey}) {
        $marc_record = $records{$reducekey};
    } else {
        $marc_record = MARC::Record->new();
    }
    $marc_record->leader($leader);
    # Check to see if _all_ the fields we're interested in are blank
    # If so, skip record.
    my $is_blank = 1;
    foreach my $map (@mapping) {
    	next if $map->{ignoreforblank};
    	next if !$map->{realcolumn};
    	my $index = $header_to_column{$map->{realcolumn}};
        next if (!defined(!$index));
        next if (!$literal_headers{$map->{realcolumn}});
        my $value = $row->[$index];
        $value =~ /^\s*(.*?)\s*$/;
        if ($value ne '') {
            $is_blank = 0;
            last;
        }
    }
    if ($is_blank && !$allow_blank) {
        warn "Record $record_count is blank, skipping\n";
        next;
    }
    # Check to see if we should skip this record
    foreach my $map (@mapping) {
        next if (!$map->{'skipcheck'} || $map->{'is_item_field'});
        # This doesn't handle values with sourcefunctions, although it could
        # be made to do so.
        my $index = $header_to_column{$map->{column}};
        my $value = $row->[$index];
        if (grep { $_->($value) } @{ $map->{'skipcheck'} }) {
            $stat_skipped++;
            next ROW;
        }
    }
    my $itemcount;
    my @postop;
    my @item_maps; # Save them up for later processing.
    foreach my $map (@mapping) {
    	my $col = $map->{column};
        push @postop, @{ $map->{'postop'} } if $map->{'postop'};
        next if !$map->{'marcsub'};
        my $is_item_field = $map->{is_item_field};
        # Items get saved and dealt with specially later
        if ($is_item_field) {
            push @item_maps, $map;
            next;
        }
        my $value = value_from_row($map, \%header_to_column, $row, $strict);
        next if (!defined $value);
        $value = clean_string($value);
        # Rewriting the value is optional, but may be useful sometimes.
        # Note that multiple values may be specified
        my @marc_values = $map->{marcsub}->($value);
        # Check for special things that may have been set
        $itemcount = $map->{'itemcount'} if ($map->{'itemcount'});
        add_marc_values($map, $strict, $record_count, $marc_record, $col, 0, $value, \@marc_values);
    }
    # Any post-processing happens here, for example responding to an
    # 'itemcount' value.
    if (@postop) {
        foreach my $op (@postop) {
            my @marcdata = $op->($marc_record);
            # If this returns data, it's a list containing the two marc
            # things and a value. This may be repeated.
            while (@marcdata) {
                my ($tag, $subfield, $value) = (shift @marcdata, shift @marcdata, shift @marcdata);
                add_marc_value($marc_record, $tag, $subfield, $value);
            }
        }
    }
    my $skip_record; # If for any reason we need to
    # This isn't a regular postop function because we want it to come last.
    if ($items_data) {
        # This handles us having a seperate item source
        my @items = get_items($items_data, $row);
        my @item_fields;
        my $base_952 = $marc_record->field('952'); # There shouldn't be more than one
            # This one will get cloned for each new record we want. If there's
            # none, then we make one later.
        $marc_record->delete_field($base_952) if defined($base_952); # Delete
            # the partial entry that we're going to be cloning.
        if (!@items) {
            debug(1, "Record $record_count has no items");
            $skip_record = $skip_no_items;
        }
        ROW: foreach my $it_row (@items) {
            # Check to see if we should skip this record
            foreach my $map (@mapping) {
                my $column = $map->{column};
                next if (!$map->{'skipcheck'} || !$map->{'is_item_field'});
                # This doesn't handle values with sourcefunctions.
                my $index = $items_data->{header_to_column}{$column};
                my $value = $it_row->[$index];
                if (grep { $_->($value) } @{ $map->{'skipcheck'} }) {
                    $stat_itemsskipped++;
                    next ROW;
                }
            }
            $stat_itemsadded++;
            my $clone_952;
            if ($base_952) {
                $clone_952 = $base_952->clone();
            } else {
            	$clone_952 = undef;
            }
            # Now for the item details we saved before, we extract the data
            foreach my $it_map (@item_maps) {
            	my $value = value_from_row($it_map, 
            	    $items_data->{header_to_column}, $it_row, $strict);
            	debug(4, "Item map: ".$it_map->{column}." got value ".(defined($value) ? $value : '[undef]'));
            	next if (!defined $value);
            	my @marc_values = $it_map->{marcsub}->($value);
                while (my ($tag, $subfield, $newvalue) = splice(@marc_values, 0, 3)) {
                    $value = $newvalue || $value;
                    next if is_marc_ok($tag, $subfield, $it_map, $strict, $record_count);
                    if ($tag ne '952') {
                        die "The MARC tag for item values must be 952. Map: ".$it_map->{column}."=".$it_map->{field}." returned ${tag}_$subfield\n";
                    }
                    debug(4, "Item column ".$it_map->{column}." has MARC tag $tag, subfield $subfield, value $value");
                    $clone_952 = add_marc_field_value('952', $clone_952, $subfield, $value);
                }
            }
            push @item_fields, $clone_952 if $clone_952;
        }
        my $itemtally;
        my $clone_record = $marc_record->clone;
        foreach my $item_952 (@item_fields) {
            $itemtally++;
            if ($item_split && ($itemtally > $item_split)) {
                # This is a bit hacky, and really the thing should be
                # refactored to allow arrays of marc records. 
            	push @records, $marc_record;
            	$marc_record = $clone_record;
            	$clone_record = $clone_record->clone;
            	$itemtally = 0;
            	debug(1, "Splitting record $record_count due to number of items");
                $stat_bibsadded++;
            }
            $marc_record->insert_grouped_field($item_952);
        }
    } else {
        # This is for the simple case where there is a field that specifies
        # how many copies of an item there are
        $stat_itemsadded++; # For the first one
        if ($itemcount && $itemcount > 1) {
            # Duplicate the 952 field to indicate a number of items
            my @item_fields = $marc_record->field('952');
            for (my $i=1; $i<$itemcount; $i++) {
                $stat_itemsadded++;
                $marc_record->insert_fields_ordered(@item_fields);
            }
        }
    }
    if (!$skip_record) {
        if ($reducekey) {
            $stat_bibsadded++ unless $records{$reducekey};
            $records{$reducekey} = $marc_record;
        } else {
            $stat_bibsadded++;
            dedup_fields($marc_record) if ($dedup_fields);
            save_record($output_fh, $marc_record);
        }
    }
}
if ($reduce) {
    foreach my $key (keys %records) {
        dedup_fields($records{$key}) if ($dedup_fields);
        save_record($output_fh, $records{$key});
    }
}
if (ref $output_fh eq 'MARC::File::XML') {
    $output_fh->close();
} else {
    close $output_fh;
}

my $status = $csv->status();
if (defined($status)) {
    print STDERR "An error occurred processing $input_file (status=$status): ".$csv->error_diag."\n";
    print STDERR "Error input: ".$csv->error_input."\n";
    print STDERR "Continuing saving what we did get.\n";
    $csv->SetDiag(0);
}

sub dedup_fields {
    my $marc_record = shift;
    my %tags;
    foreach my $field ($marc_record->fields()) {
        $tags{$field->tag()}++;
    }
    $Data::Dumper::Sortkeys = 1;
    foreach my $tag (keys %tags) {
        if ($tags{$tag} > 1) {
            my @fields = $marc_record->field($tag);
            next unless (scalar(@fields) > 1);
            foreach my $field1 (@fields) {
                my @fieldscmp = $marc_record->field($tag);
                my $duplicate;
                next unless (scalar(@fieldscmp) > 1);
                foreach my $field2 (@fieldscmp) {
                    next if ($field1 == $field2);
                    if (Data::Dumper::Dumper($field1) eq Data::Dumper::Dumper($field2)) {
                        $duplicate = 1;
                        last;
                    }
                }
                $marc_record->delete_fields($field1) if $duplicate;
            }
        }
    }
    return $marc_record;
}

sub open_output_file {
	my ($filename) = @_;

    my $file;
    if ($marc_format eq 'marcxml') {
        MARC::File::XML->default_record_format('MARC21');
        $file = MARC::File::XML->out($output_file);
    } else {
        open($file, '>:utf8', $output_file) or
            die "Unable to open $output_file for writing: $!\n";
    }
    return $file;
}

sub save_record {
	my ($handle, $record) = @_;
    if ($preview && !$handle) {
        print $record->as_formatted(), "\n";
    } else {
        # TODO change this so that it can work with any MARC::File subclass
        if ($marc_format eq 'marcxml') {
            $handle->write($record);
        } else {
            $record->encoding('UTF-8');
            print $handle $record->as_usmarc();
        }
    }
}

save_unused_report();
print "Records read: $stat_records\tBibs added: $stat_bibsadded\tItems added: $stat_itemsadded\tRecords skipped: $stat_skipped\tItems skipped: $stat_itemsskipped\n" unless $quiet;

sub debug {
    my ($level, $message) = @_;
    return if ($level > $debug_level);
    print STDERR "csvtomarc: debug: $message\n";
}

# Simplistically, this converts a Koha field to its MARC values, however
# it will also handle the special forms like 'marc:' and can attach
# functions where they're needed.
# Args: $col - the column name, \%map the map with a 'field' value that
# is parsed.
# The data is added to \%map, the most important bit is a sub
# 'marcsub' that takes the input provided and 
sub field_to_mapping {
    my ($col, $map) = @_;

    my ($marcsub, $fieldname);
    my $field = $map->{'field'};
    my $required = $map->{'required'};
    my $optional = $map->{'optional'};
    
    $fieldname = $field;
    if ($field =~ /^marc:/) {
        my ($tag, $subfield) = $field =~ m/^marc:(\d*)_(.)$/;
        ($tag, $subfield) = $field =~ m#^marc:(00\d)/(..)$# unless (defined($tag) && defined($subfield));
        die "$field is not a valid MARC specifier.\n" 
            if (!defined($tag) || !defined($subfield));
        # 'newfield' specifies that we want to create new MARC fields
        # for each entry, rather than just subfields
        $map->{'newfield'} = 1;
        $marcsub = sub {
            return ($tag, $subfield);
        };
        $fieldname = $field;
    } elsif ($field =~ /^multimarc:r/) {
        my ($field_str) = $field =~ m/^multimarc:r:(.*)$/;
        $map->{'newfield'} = 0;
        $marcsub = curry(\&multi_marc, $field_str);
    } elsif ($field =~ /^multimarc:/) {
        my ($field_str) = $field =~ m/^multimarc:(.*)$/;
        $map->{'newfield'} = 1;
        $marcsub = curry(\&multi_marc, $field_str);
    } elsif ($field =~ /^special:isbn/) {
        $marcsub = curry(\&is_isbn_issn, $required, $optional, $strict);
    } elsif ($field =~ /^special:title$/) {
        $marcsub = curry(\&fix_title, $required, $optional, $strict);
    } elsif ($field =~ /^special:titleparts/) {
        $marcsub = curry(\&fix_title_parts, $required, $optional, $strict);
    } elsif ($field =~ /^special:count/) {
        # This is because it doesn't produce a MARC record, and we don't
        # want the system to complain.
        $map->{'required'} = 0;
        $map->{'optional'} = 1;
        $marcsub = sub {
            my $value = shift;
            # Force it to be a number
            ($value) = $value =~ /(\d+)/;
            $value = 1 if (!$value);
            $map->{'itemcount'} = $value;
            return undef;
        };
    } elsif ($field =~ /^skipif:/) {
        my ($regex) = $field =~ m/^skipif:(.*)$/;
        push @{$map->{'skipcheck'}}, curry(\&skipif, $regex);
    } elsif ($field =~ /^append:/) {
        my ($dest) = $field =~ m/^append:(.*)$/;
        $map->{'required'} = 0;
        $map->{'optional'} = 1;
        $marcsub = curry(\&append_field, 'append', $dest);
        push @{$map->{'postop'}}, curry(\&append_field, 'save', $dest);
    } elsif ($field =~ /^special:language:/) {
        my ($tag,$subfield) = $field =~ m/^special:language:(\d*)_(.)$/;
        die "$field is not a valid MARC specifier.\n"
            if (!defined($tag) || !defined($subfield));
        die "No languages have been loaded. See the documentation for --lang.\n" 
            if (!%language_map);
        $marcsub = sub { # Probably should be a named sub by now
        	my $val = shift;
        	$val = [ $val ] if (ref($val) ne 'ARRAY');
        	my @res;
        	foreach my $v (@$val) {
                my $res = $language_map{lc($v)};
                if (!$res) {
                    warn "Unknown language: $v\n";
                    $res = $v;
                }
                push @res, ($tag, $subfield, $res);
            }
            return @res;
        }
    } else {
        my ($tag, $subfield);
        ($tag, $subfield, $fieldname) = get_marc_field_from_koha($field);
        die "$field doesn't appear to be a valid Koha field name.\n" 
            if (!defined($tag) || !defined($subfield));
        $marcsub = sub {
            return ($tag, $subfield);
        };
    }
    $map->{'marcsub'} = $marcsub;
    $map->{'fullfield'} = $fieldname;
}

sub get_marc_field_from_koha {
    my ($field) = @_;
    my ($fieldname, $tag, $seen, $subfield);
    my @kohafieldtypes = ('', 'biblio.', 'biblioitems.', 'items.');
    return if $skip_koha;
    foreach (@kohafieldtypes) {
        my $fieldname_tmp = $_.$field;
        my ($tag_tmp, $subfield_tmp) = 
            C4::Biblio::GetMarcFromKohaField($fieldname_tmp, '');
        die "$field has a duplicate named value with $fieldname_tmp and $fieldname. Specify the full name that you want to to use to avoid this.\n" if ($tag && $seen);
        if ($tag_tmp) {
            $fieldname = $fieldname_tmp;
            $tag = $tag_tmp;
            $subfield = $subfield_tmp;
        }
    }
    return ($tag, $subfield, $fieldname);
}

# A reasonably simple, if not elegant, way to do currying in Perl.
sub curry {
    my $func = shift;
    my $args = \@_;
    sub {
        $func->(@$args, @_)
    };
}

# This takes a CSV column specification and determines if it's a function or
# not. If it is, it returns the function reference as the first result. The
# second result is whether the source data should be the items (true) or the
# biblios (false.)
#
# Note: at some stage I'd like to make this able to handle complex nested 
# functions.
sub mapping_source {
    my ($mapping,$is_items) = @_;
    if ($mapping =~ /^item:/) {
        my ($field) = $mapping =~ /^item:(.*)$/;
        # $field may be either a column name or a function specification
        return (mapping_source($field, 1));
    } elsif ($mapping =~ /^func:/) {
        my ($func,undef,$arg) = $mapping =~ /^func:([^:]*)(:(.*))?$/;
        die "The function '$func' doesn't exist\n"
            if (!exists($source_functions{$func}));
        my $realcolumn = undef;
        if (my $re = $source_functions{"${func}_column_re"}) {
            ($realcolumn) = $mapping =~ m/$re/;
        }
        return (curry($source_functions{$func}, $arg), $is_items, $mapping, $realcolumn);
    } else {
        if ( ($is_items && !exists $items_data->{header_to_column}->{$mapping}) ||
        	 (!$is_items && !exists $header_to_column{$mapping}) ) {
            die "Missing column specified in the mapping: $mapping doesn't exist in ".($is_items ? $items_file : $input_file)."\n";
        }
        return (undef, $is_items, $mapping, $mapping);
    }
}

# This wires in the functions to handle parsing of Liberty format MARC records.
# These records are a single string that contains newlines and characters
# to break up the content in required places. Something like:
# |# 0^aTime^vJuvenile fiction.
# |# 0^aToy and movable books^vSpecimens.
# |# 0^aBoard books.
# (where the '|' is to be ignored, but everything else is literal.) The numbers
# are the indicators, # indicates the start of a record and ^ of a subfield.
# The newline appears to be reliably there. Who knows what happens if there
# is a '^' in an unexpected place.
sub create_liberty_map {
	my $header = shift;

	my %map;
    # This is all the source stuff, it's pretty easy: we just want the
    # literal value.
	$map{sourcefunc} = undef;
	$map{is_item_field} = 0;
	$map{column} = $header;
	$map{realcolumn} = $header;

    # This is the output side. Mostly we just pass off to a function that 
    # understands things.
    $map{field} = $map{fullfield} = "liberty:$header";
    $map{required} = 0;
    $map{optional} = 1;
    $map{marcsub} = curry(\&liberty_field, $header);
    $map{ignoreforblank} = 0;
    $map{repeatfield} = 0;

    return \%map;
}

# This takes a field with a leader and puts it in as the MARC leader.
sub create_leader_map {
	my $header = shift;

	my %map;
    $map{sourcefunc} = undef;
    $map{is_item_field} = 0;
    $map{column} = $map{realcolumn} = $header;

    $map{field} = $map{fullfield} = "marcleader";
    $map{required} = 1;
    $map{optional} = 0;
    $map{ignoreforblank} = 1;
    $map{repeatfield} = 0;

    $map{marcsub} = curry(\&add_leader, 'save');
    $map{postop} = [ curry(\&add_leader, 'write') ];
    return \%map;
}

# This takes the marc record that's supplied to the function and sets the
# leader on it to be the value. It actually saves it, and adds it as a postop.
# There should only be one leader per record, or odd things will happen
# that you probably don't want.
my $saved_leader;
sub add_leader {
    my ($op, $value_or_record) = @_;
    if ($op eq 'save') {
    	$saved_leader = $value_or_record;
    } elsif ($op eq 'write') {
        $value_or_record->leader($saved_leader) if $saved_leader;
        undef $saved_leader;
    }
    return ();
}

# This will determine if the supplied string is a valid ISBN or ISSN, and
# assign it to the appropriate field. It also takes arguments in order to
# determine whether the field is compulsory or not, although currently 
# these are ignored.
# It will return the MARC values (tag, subfield) for whichever field it
# should be, along with the cleaned up IS[BS]N, or will return undef.
my (@isbnmarc, @issnmarc);
sub is_isbn_issn {
    my ($required, $optional, $strict, $code) = @_;

    return if $skip_koha;

    # Just do this the first time around
    if (!@isbnmarc) {
        @isbnmarc = C4::Biblio::GetMarcFromKohaField('biblioitems.isbn','');
        @issnmarc = C4::Biblio::GetMarcFromKohaField('biblioitems.issn','');
        die "Unable to find MARC mappings for ISBN or ISSN\n" 
            if (!@isbnmarc || !@issnmarc);
    }

    # do some cleanup by taking the first sequence of valid characters we 
    # find. We search down to length 5 because bad spreadsheet use can
    # remove leading zeros.
    $code = uc($code);
    ($code) = $code =~ /([0-9X\-]{8,16})/;

    return undef if (!$code);
    
    my $cleaned_code;
    my $isbnobj = Business::ISBN->new($cleaned_code = sprintf("%010s",$code));
    return (@isbnmarc, $cleaned_code) if ($isbnobj && $isbnobj->is_valid);
    debug(2, "$cleaned_code is not a valid ISBN (10-digit)");

    $isbnobj = Business::ISBN->new($cleaned_code = sprintf("%013s",$code));
    return (@isbnmarc, $cleaned_code) if ($isbnobj && $isbnobj->is_valid);
    debug(2, "$cleaned_code is not a valid ISBN (13-digit)");

    my $issnobj = Business::ISSN->new($cleaned_code = sprintf("%08s",$code));
    return (@issnmarc, $cleaned_code) if ($issnobj && $issnobj->is_valid);
    debug(2, "$cleaned_code is not a valid ISSN");

    return undef;
}

# Splits a title on ':' and '/'.  The part before the ':' (or '/' if there's 
# no ':') goes into 245$a (title), the part between the ':' and the '/' or
# end of string goes into 245$b (remainder of title) and anything after '/'
# goes into 245$c (statement of responsibility.)
sub fix_title {
    my ($required, $optional, $strict, $title) = @_;
    
    # Pull apart the bits. Any of these may be undef or '' if that part isn't
    # specified.
    my ($title_part) = $title =~ /^([^\/]+?(?:\/| :|$))/;
    my ($remain_part) = $title =~ / :\s*([^\/]+(?:\/|$))/;
    my ($statem_part) = $title =~ /\/\s*(.*)$/;
    
    die "'$title' doesn't contain a title part\n" if (($required && $strict) || (!$optional && !$strict)) && !$title_part;

    debug(3, "Split '$title' into [".($title_part || '')."] [".($remain_part || '')."] [".($statem_part || '')."]");
    my @result;
    push @result, ('245', 'a', $title_part) if $title_part;
    push @result, ('245', 'b', $remain_part) if $remain_part;
    push @result, ('245', 'c', $statem_part) if $statem_part;
    return @result;
}

# Takes a array of title parts (up to three elements: title, remainder,
# statement) and outputs them in to the appropriate MARC fields, and appends
# punctuation if required.
sub fix_title_parts {
    my ($required, $optional, $strict, $title) = @_;

    my ($t, $r, $s) = @$title;
    
    if ($t && $r && $t !~ /:$/) {
    	$t .= ' :';
    } elsif ($t && $s && $t !~ m|/$|) {
    	$t .= ' /';
    }
    if ($r && $s && $t !~ m|/$|) {
    	$s .= ' /';
    }
    my @result;
    push @result, ('245', 'a', $t) if $t;
    push @result, ('245', 'b', $r) if $r;
    push @result, ('245', 'c', $s) if $s;
    return @result;
}

# This populates multiple MARC fields with a the source from an array of values.
# Special things: ... at the end means 'repeat the final value forever', '_'
# anywhere means 'ignore what goes in this place.'
sub multi_marc {
    my ($field_str, $values) = @_;
    $values = [ $values ] if (ref($values) ne 'ARRAY');

    my @fields = split(/:/, $field_str);
    my $continue;
    if ($fields[-1] eq '...') {
    	pop @fields;
    	my $f = $fields[-1];
        # Make sure there are more fields than values
    	push @fields, $f foreach (@$values);
    }
    my @result;
    my ($f, $v);
    while (($f = shift @fields) && ($v = shift(@$values))) {
    	next if ($f eq '_');
        my ($t,$sf) = $f =~ /^(\d*)_(.)$/;
        push @result, ($t, $sf, $v);
    }
    return @result;
}

# This parses a liberty-style marc field, and gives us MARC objects in return.
# The liberty stuff has more information than we normally deal with (like
# indicators) so we have to be able to include that, hence returning MARC
# records directly.
sub liberty_field {
    my ($header, $value) = @_;

    my ($tag_id) = $header =~ /^T(\d\d\d)$/;
    my @marc;
    my @fields = split(/[\n\f]/, $value);
    # Each of these fields should be of the form:
    # '#ii^aStuffstuff^bblahblah'
    # where 'ii' are the two indicator numbers, or spaces.
    foreach my $f (@fields) {
    	my $marc;
    	if ($tag_id =~ /^00/) {
            # MARC fields starting in 00 behave differently to those that
            # don't. Surprise, huh? In particular, no subfields.
            die "The Liberty MARC appears to have an unhappy control field. Suspect field contains:\n$value\n"
                if ($f !~ /^#/);
            my ($val) = $f =~ /^#(.*)$/;
            $marc = MARC::Field->new($tag_id, $val);
        } else {
            # This happens when there are no subfields (which shouldn't be
            # possible, but Liberty.)
        	next if ($f =~ /^#$/);
            # This turns a non-control field without subfields into one with
            # a single subfield ('a') and the value in that. This shouldn't
            # be necessary, but Liberty. Only if it's less than 100 though,
            # over that should be reviewed probably.
            if ($f =~ /^#..[^^]/ && $tag_id =~ /^0/) {
                $f = '#  ^a'.substr($f, 1);
            }
            # Sanity check to make sure that all newlines are at a field boundry
            die "The Liberty MARC at $header appears to have an invalid newline or indicators. Suspect field contents:\n[$value]\n"
                if ($f !~ /^#[\da-z|_# ]{2}(?:\^|$)/) ;
            my ($i1, $i2) = $f =~ /^#([\da-z|_# ])([\da-z|_# ])/;
            die "Undefined indicators. WTF? Record:\n[$value]\n"
                if (!defined($i1) || !defined($i2));
            # This seems to occur a lot, so we turn it into ' ' because '|'
            # and '_' is not allowed. But, Liberty.
            $i1 = ' ' if $i1 =~ /[|_#]/;
            $i2 = ' ' if $i2 =~ /[|_#]/;
            # Split on '^' now
            my @subfields = split(/\^/, $f);
            shift @subfields; # Discard the indicators
            foreach my $s (@subfields) {
                my ($field_id, $string) = $s =~ /^(.)(.*)$/;
                if ($marc) {
                    $marc->add_subfields($field_id, $string);
                } else {
                    $marc = MARC::Field->new($tag_id, $i1, $i2,
                        $field_id, $string);
                }
            }
        }
        push @marc, $marc;
    }
    return @marc;
}

# This is a source function that splits the field provided as the second
# argument (from the command)  on the character provided by the first 
# argument.
sub split_source {
    my $arg=shift;
    my $header_to_column=shift;
    my $row=shift;

    my ($splitval, $source) = split(/:/, $arg, 2);
    die "Unable to split as the column '$source' doesn't exist.\n" if (!exists($header_to_column->{$source}));  
    my $value = $row->[$header_to_column->{$source}];
    my @split;
    if ($splitval ne '\n') { # Note that these are single quotes
        @split = split(/\Q$splitval\E/, $value);
    } else {
    	@split = split(/[\n\r]+/, $value);
    }
    $_ =~ s/^\s*(.*?)\s*$/$1/ foreach (@split);
    return \@split;
}

# This is a source function that counts the number of items that would be
# returned by the 'split' function.
sub splitcount_source {
    my $vals = split_source(@_);
    return scalar(@$vals);
}

# This is similar to split, however it will split into (at most) two parts,
# with the split point being the last instance of the split character.
sub splitlast_source {
	my $arg=shift;
	my $header_to_column=shift;
	my $row=shift;

    my ($splitval, $source) = split(/:/, $arg, 2);
    die "Unable to splitlast as the column '$source' doesn't exist.\n" if (!exists($header_to_column->{$source}));  
    my $value = $row->[$header_to_column->{$source}];

    # Handle the case of needing to split it at all first
    # Make this handle \n at some stage.
    if ($value =~ m/\Q$splitval\E/) {
        # Split
        my ($first, $second) = $value =~ m/^(.*)\Q$splitval\E\s*(.*)$/;
        return [ $first, $second ];
    } else {
        # Don't split
        return [ $value ];
    }
}

# This is a source function that prefixes a provided string to the value.
sub prefix_source {
    my ($arg, $header_to_column, $row) = @_;

    my ($text, $source) = $arg =~ m/^(.*):(.*)$/;
    die "Invalid arguments to 'prefix': $arg \n" if (!$text || !$source);
    my $idx = $header_to_column->{$source};
    die "Unknown column '$source' specified in prefix source: '$arg'\n" if !defined($idx);
    my $value = $row->[$header_to_column->{$source}];
    return undef if (!$value);
    return $text.$value;
}

sub text_source {
    my ($arg, $header_to_column, $row) = @_;

    my ($text) = $arg =~ m/^(.*)$/;
    die "Invalid arguments to 'text': $arg \n" if (!$text);
    return $text;
}

sub titlecase_source {
    my ($arg, $header_to_column, $row) = @_;

    my ($source) = $arg =~ m/^(.*)$/;
    my $idx = $header_to_column->{$source};
    die "Unknown column '$source' specified in titlecase source: '$arg'\n" if !defined($idx);
    my $value = $row->[$header_to_column->{$source}];
    return undef if (!$value);
    $value =~ tr/[A-Z]/[a-z]/;
    $value =~ s/(\b)([a-z])/\1\u\2/g;
    return $value;
}

# This is a source function that does a series of regex tests, and returns
# a specified value when it first sees a match
sub ifmatch_source {
    my	( $arg, $header_to_column, $row )	= @_;
    my @args = split(/:/, $arg);
    my $anchor = 0;
    if ($args[0] eq 'anchor') {
    	$anchor = 1;
    	shift @args;
    }
    my $col_header = pop @args;
    my $col_idx = $header_to_column->{$col_header};
    die "Unknown column '$col_header' specified in mapping source: '$arg'\n"
        if (!defined($col_idx));
    die "Incorrect number of arguments provided: '$arg'\n" if (@args % 2 == 1);
    my $value = $row->[$col_idx];
    return if (!@args);
    my $def_value;
    if ($args[0] =~ /default/i) {
    	shift @args;
    	$def_value = shift @args;
    }
    while (@args) {
    	my $re = shift @args;
    	$re = "^$re\$" if $anchor;
    	my $result = shift @args;
        if ($value =~ /$re/i) {
            debug(4, $re." matches $value, returning $result");
        	return $result;
        };
    }
    debug(4, "Matching for '$arg' against '$value' will return a default value");
    return undef if (!$def_value);
    return $value if $def_value eq '*';
    return $def_value;
}

# This allows simple combinations of columns to be combined by applying
# a sequence of operations to them. Currently the operations are 'upto'
# and 'append'. 
sub combine_source {
    my ($arg, $header_to_column, $row) = @_;

    my @args = split(/:/, $arg);
    my $result;
    while (@args) {
        my $op = shift @args;
        # Here's the deal: no adding more stuff here until the copy-pasta bits
        # are refactored out.
        if ($op eq 'upto') {
            my $char = shift @args;
            my $col = shift @args;
            my $idx = $header_to_column->{$col};
            die "Unknown column '$col' specified in mapping source: '$arg'\n" if (!defined($idx));
            my $value = $row->[$idx];
            next if !$value;
            my ($firstpart) = $value =~ /^(.*?)\s*\Q$char\E/;
            $firstpart = $char if (!$firstpart);
            $result .= $firstpart;
        } elsif ($op eq 'after') {
            my $char = shift @args;
            my $col = shift @args;
            my $idx = $header_to_column->{$col};
            die "Unknown column '$col' specified in mapping source: '$arg'\n" if (!defined($idx));
            my $value = $row->[$idx];
            next if !$value;
            my ($lastpart) = $value =~ /^.*?\Q$char\E\s*(.*)$/;
            $lastpart = $char if (!$lastpart);
            $result .= $lastpart;
            debug(4, "Last part of $value (char=$char) is $lastpart");
        } elsif ($op eq 'append') {
            my $char = shift @args;
            my $col = shift @args;
            my $idx = $header_to_column->{$col};
            die "Unknown column '$col' specified in mapping source: '$arg'\n" if (!defined($idx));
            my $value = $row->[$idx];
            next if !$value;
            $result .= $char . $value;
        } elsif ($op eq 'text') {
            $result .= shift @args;
        } else {
        	die "Unknown argument '$op' in '$arg'.\n";
        }
    }
    return $result;
}

# This adds marc subfields or fields to a record. The input should be an
# arrayref of either MARC::Fields, or triples of (tag, subfield, newvalue.)
sub add_marc_values {
	my ($map, $strict, $record_count, $marc_record, $col, $isitem, 
	    $default_value, $list) = @_;

	return if (!@$list);
	die "add_marc_values is not yet able to handle item fields. Fix this too."
	    if ($isitem);

	if (ref($list->[0]) eq '') {
        # then it's triples of strings
        while (my ($tag, $subfield, $newvalue) = splice(@$list, 0, 3)) {
            my $value = $newvalue || $default_value;
            # Read the doc for is_marc_ok if you think this is weird
            # It won't stop being weird, but it'll make sense.
            next if is_marc_ok($tag, $subfield, $map, $strict, $record_count);
            debug(3, "Column $col has MARC tag $tag, subfield $subfield");
            add_marc_value($marc_record, $tag, $subfield, $value, $map->{'newfield'} || $map->{'repeatfield'});
        }
    } else {
        # It's MARC::Field
        $marc_record->insert_fields_ordered(@$list);
    }
}

# Adds a value to the supplied MARC record, understanding if the value is
# an arrayref. $newfield specifies that we should create a new field when
# we get duplicate subfields, rather than just adding the subfield.
sub add_marc_value {
    my ($marc_record, $tag, $subfield, $value, $newfield) = @_;

    $value = [ $value ] if (!ref($value));
    return if (!@$value);

    if ($tag =~ m/00\d/) {
        if (my $field = $marc_record->field($tag)) {
            my $data = $field->data();
            substr($data, $subfield, length $value->[0]) = $value->[0];
            $field->update($data);
        } else {
            $marc_record->add_fields($tag, ' ' x $subfield . $value->[0]);
        } 
        return;
    }
    foreach my $v (@$value) {
    	my $field;
        if ($field = $marc_record->field($tag)) {
            my @fields = $marc_record->field($tag);
            $field = pop @fields;
            if (!$newfield || !defined($field->subfield($subfield))) {
                $field->add_subfields($subfield => $v);
            } elsif ($newfield == -1) {
                $field->update($subfield => $v);
            } else {
                $marc_record->add_fields($tag, " ", " ", $subfield => $v);
            }
        } else {
            $marc_record->add_fields($tag, " ", " ", $subfield => $v);
        } 
    }
}

# Similar to add_marc_value, except it expects to be provided a field, and
# adds the value to that.
sub add_marc_field_value {
    my ($tag, $marc_field, $subfield, $value) = @_;

    $value = [ $value ] if (!ref($value));
    return if (!@$value);

    if ($tag =~ m/00\d/) {
        if (!defined $marc_field) {
            $marc_field = MARC::Field->new($tag, ' ' x $subfield . $value->[0]);
        } else {
            my $data = $marc_field->data();
            substr($data, $subfield, length $value->[0]) = $value->[0];
            $marc_field->update($data);
        }
        return $marc_field;
    }
    if (!defined $marc_field) {
    	$marc_field = MARC::Field->new($tag, ' ', ' ',
    	    $subfield, $value->[0]);
    	shift @$value;
    }
    foreach my $v (@$value) {
    	$marc_field->add_subfields($subfield => $v);
    }
    return $marc_field;
}

# This function does two things: it saves up the values sent to it, and
# it later requests them to be saved to a MARC record.
my %fields;
sub append_field {
    my ($op, $dest, $value, $record) = @_;

    if ($op eq 'append') {
        return undef if ($value eq '');
        if ($fields{$dest}) {
            $fields{$dest} .= "\n\n$value";
        } else {
            $fields{$dest} = $value;
        }
        return undef;
    } elsif ($op eq 'save') {
        return undef if (!$fields{$dest});
        my $text = $fields{$dest};
        my @destmarc;
        my @m;
        if ($dest =~ m/^marc:(\d\d\d)_(.)$/) {
        	@m = ($1, $2);
        } else{
            @m = get_marc_field_from_koha($dest);
            die "Unable to find MARC mapping for the field $dest" if (!@m || !$m[0]);
        }
        push @destmarc, @m[0,1];
        # If there's already content in the field we're interested in, we
        # append to it and remove it. This may have to change some time in the
        # future, but hopefully not just yet.
        if ($record) {
            my $curr_text = $record->subfield($m[0], $m[1]);
            if ($curr_text) {
                $text = "$curr_text\n\n$text";
                $record->field($m[0])->subfield($m[1]);
            }
        }
        push @destmarc, $text;
        delete $fields{$dest};
        return @destmarc;
    } else {
        die "append_field called with invalid operation '$op'\n";
    }
}

sub skipif {
    my ($pattern, $value) = @_;
    return $value =~ m/$pattern/;
}

# This loads the items data, and configures an object with all the data
# required to use it. Really, this should be OO, but it's not.
my %unused_items;
sub load_items_data {
    my ($file, $idcolumn, $field_sep_char) = @_;

    debug(1, "Loading items file $file using mapping $idcolumn");
    my $result={};
    # Take the mapping to start with. It is of the form "biblios column=items column"
    # where the column value is the name of the column.
    my ($biblio_col, $item_col) = split(/=/, $idcolumn);
    if (!$biblio_col || !$item_col) {
    	die "The item link mapping must be of the form: biblios column name=items column name.\n";
    }
    $result->{biblio_col} = $biblio_col;
    $result->{item_col}   = $item_col;
    my $csv = Text::CSV_XS->new({
            binary  => 1,   # binary handles funny line endings and macrons etc.
            eol     => $/,
            allow_loose_quotes => $loosequotes,
            escape_char => ( $loosequotes ? '' : '"'),
    	    sep_char => $field_sep_char,
        });
    open my $csvfile, '<', $file
        or die "Unable to open $file: $!\n";
    my $header_row = $csv->getline($csvfile);
    my $count=0;
    my %header_to_column = map { $_ => $count++ } @$header_row;
    if (!exists($header_to_column{$item_col})) {
    	die "The item file column '$item_col' could not be found.\n";
    }
    $result->{header_to_column} = \%header_to_column;
    my $key_header = $header_to_column{$item_col};
    $count=0;
    while(my $row = $csv->getline($csvfile)) {
    	debug(3, "Loading item with key value: ".$row->[$key_header]);
        push @{ $result->{rows}{$row->[$key_header]} }, $row;
        $unused_items{$row->[$key_header]} = 1 if ($unused_items_report);
        $count++;
    }
    close $csvfile;
    debug(1, "Done loading the items file: $count items found\n");
    return $result;
}

# This gets the item rows for the supplied biblio row 
sub get_items {
	my ($items_data, $biblios_row) = @_;
	my $key = $biblios_row->[$header_to_column{$items_data->{biblio_col}}];
	my $result = $items_data->{rows}{$key};
	delete($unused_items{$key}) if ($unused_items_report);
	return @$result if $result;
	return ();
}

# Save unused items report
sub save_unused_report {
	return unless ($unused_items_report);
	open my $fh, '>', $unused_items_report or die "Can't open $unused_items_report for writing: $!\n";
    print $fh join("\n", sort keys %unused_items)."\n";
	close $fh;
}


# Given the various things needed to calculate what a value (spreadsheet cell)
# is, this calculates that value. It accounts for running functions to
# get the value, or just doing it literally.
sub value_from_row {
    my ($map, $header_to_column, $row, $strict) = @_;
    my $value;
    if ($map->{sourcefunc}) {
        $value = $map->{sourcefunc}->($header_to_column, $row);
    } else {
        my $col = $map->{column};
        my $index = $header_to_column->{$col};
        $value = $row->[$index];
        die "Something strange happened with the parsing: undef value encountered.\ncol=$col\tindex=$index\trecord=$record_count\nRow:\n\"".join('","',@$row)."\"\n"
            if (!defined($value));
        $value =~ s/^\s*(.*?)\s*$/$1/; # trim whitespace
        # Check the field is OK
        die "There is an empty value in record $record_count, field $col (strict is on and this field is not optional)\n@$row\n"
            if ($strict && !$map->{optional} && $value eq '');
        debug(1,"There is an empty value in record $record_count, field $col (strict is off, ignoring")
            if (!$strict && !$map->{optional} && $value eq '');
        #die "There is an empty value in record $record_count, field $col (this is compulsory)\n@$row\n"
        #    if ($map->{required} && $value eq '');
        # If we get here and the value is empty, it's OK and we skip this
        # field.
        return if $value eq '';
    }
    return $value;
}

# Checks to see if the MARC is OK. It will die if it's not. If it returns true,
# then it's blank but not a problem (and so attempting to add it should be
# skipped). If it returns false then continue on (this seems weird, but makes
# tests easy, e.g. 'next if is_marc_ok(...)')
sub is_marc_ok {
    my ($tag, $subfield, $map, $strict, $record_count) = @_;
    if (!defined($tag) || !defined($subfield)) {
        return 1 if $map->{'optional'};
        my $col = $map->{column};
        die "There is an invalid value in record $record_count, field $col (this is compulsory)\n" if ($map->{required});
        die "There is an invalid value in record $record_count, field $col (strict is on and this field is not optional)\n" if (!$map->{optional});
        debug(1, "There is an invalid value in record $record_count, field $col (strict is off, ignoring") if (!$strict && !$map->{optional});
        return 1;
    }
    return 0;
}

# This loads a language file so that language names can be mapped to MARC codes.
# This file must be of a form comparable to that at 
# http://www.loc.gov/standards/codelists/languages.xml
# Takes in a filename, and returns a hash of lc(language name) to language code
sub load_langs {
	debug(2, "Loading languages");
	my $file = shift;

    my $parser = XML::LibXML->new();
    open my $fh, '<', $file or die "Error opening languages file $file: $!\n";
    binmode $fh;
    my $doc = $parser->parse_fh($fh);
    my $xc = XML::LibXML::XPathContext->new($doc);
    $xc->registerNs('cl', 'info:lc/xmlns/codelist-v1');

    my %result;

    foreach my $lang_node ($xc->findnodes('//cl:language')) {
        my ($code) = map { $_->to_literal } $xc->findnodes('./cl:code', $lang_node);
    	$code = lc($code);
    	my @names = map { lc($_->to_literal) } $xc->findnodes('./cl:name', $lang_node);
    	push @names, map { lc($_->to_literal) } $xc->findnodes('./cl:uf/cl:name', $lang_node);
        $result{$_} = $code foreach (@names);	
        $result{$code} = $code;
    }
    close $fh;
	debug(3, "Done loading languages");
	return %result;
}

sub clean_string {
    my $value = shift;
    # \a (^G, \x007) is a special character that gets turned into a ',' on
    # write. This lets troublesome commas be escaped.
    $value =~ s/\a/,/g;
    # Remove some smart quote madness that gets into CSVs
    $value = fix_latin($value) if ref($value) eq '';
    if (ref($value) eq 'ARRAY') {
        $_ = fix_latin($_) foreach (@$value);
    }
    return $value;
}
