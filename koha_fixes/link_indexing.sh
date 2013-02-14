#
# symlinks the zebra index configs on a dev install, so that when they are updated in the code, the update takes effect 
# in the instance!
#
rm ~/koha-dev/etc/zebradb/ccl.properties
ln -s ~/kohaclone/etc/zebradb/ccl.properties ~/koha-dev/etc/zebradb/ccl.properties
#
rm ~/koha-dev/etc/zebradb/biblios/etc/bib1.att
ln -s ~/kohaclone/etc/zebradb/biblios/etc/bib1.att ~/koha-dev/etc/zebradb/biblios/etc/bib1.att
#
rm ~/koha-dev/etc/zebradb/authorities/etc/bib1.att
ln -s ~/kohaclone/etc/zebradb/authorities/etc/bib1.att ~/koha-dev/etc/zebradb/authorities/etc/bib1.att
#
rm ~/koha-dev/etc/zebradb/marc_defs/marc21/biblios/record.abs
ln -s ~/kohaclone/etc/zebradb/marc_defs/marc21/biblios/record.abs ~/koha-dev/etc/zebradb/marc_defs/marc21/biblios/record.abs
#
rm ~/koha-dev/etc/zebradb/etc/word-phrase-utf.chr
ln -s ~/kohaclone/etc/zebradb/etc/word-phrase-utf.chr ~/koha-dev/etc/zebradb/etc/word-phrase-utf.chr
#
rm ~/koha-dev/etc/zebradb/marc_defs/unimarc/authorities/record.abs
ln -s ~/kohaclone/etc/zebradb/marc_defs/unimarc/authorities/record.abs ~/koha-dev/etc/zebradb/marc_defs/unimarc/authorities/record.abs
#
rm ~/koha-dev/etc/zebradb/marc_defs/marc21/authorities/record.abs
ln -s ~/kohaclone/etc/zebradb/marc_defs/marc21/authorities/record.abs ~/koha-dev/etc/zebradb/marc_defs/marc21/authorities/record.abs
#
rm ~/koha-dev/etc/zebradb/marc_defs/marc21/authorities/authority-koha-indexdefs.xml
ln -s ~/kohaclone/etc/zebradb/marc_defs/marc21/authorities/authority-koha-indexdefs.xml ~/koha-dev/etc/zebradb/marc_defs/marc21/authorities/authority-koha-indexdefs.xml
#
rm ~/koha-dev/etc/zebradb/marc_defs/marc21/authorities/authority-zebra-indexdefs.xsl
ln -s ~/kohaclone/etc/zebradb/marc_defs/marc21/authorities/authority-zebra-indexdefs.xsl ~/koha-dev/etc/zebradb/marc_defs/marc21/authorities/authority-zebra-indexdefs.xsl
#
rm ~/koha-dev/etc/zebradb/marc_defs/marc21/authorities/koha-indexdefs-to-zebra.xsl
ln -s ~/kohaclone/etc/zebradb/marc_defs/marc21/authorities/koha-indexdefs-to-zebra.xsl ~/koha-dev/etc/zebradb/marc_defs/marc21/authorities/koha-indexdefs-to-zebra.xsl
#

