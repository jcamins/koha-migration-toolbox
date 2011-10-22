USING THIS TOOL:

You will need to customize iii_to_marcxml.xsl to match your Millennium codes and their mappings to Koha.  Two examples have been provided, iii_to_marcxml_nyuhsl and iii_to_marcxml_CCA, to show how such customizations and mappings are possible with only XSLT.

CHANGES TO MAKE TO CODE BEFORE RUNNING:

-  $IIIserver can be defined on line 64 of iii_importer.pl.  This will save you from having to enter it at  the prompt every time.

-  Depending on your server, you may need to change the call to Xalan, either by changing it's exact call, or replacing it with a call to different processor

-  You can specify a different import tool on line 630.  The bulkmarcimport tool built into Koha should suffice in nearly all circumstances

-  Depending on whether you have a production or dev install, you may need to change the -I in the perl call on line 653 to match your PERL5LIB variable

