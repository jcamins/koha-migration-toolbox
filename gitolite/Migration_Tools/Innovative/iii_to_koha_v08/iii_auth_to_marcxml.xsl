<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
	xmlns:marc="http://www.loc.gov/MARC21/slim"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" indent="yes" encoding="UTF-8"/>

<xsl:template match="RECORDBATCH">
	<collection xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
		<xsl:apply-templates />
	</collection>
</xsl:template>

<xsl:template match="FULLRECORD">
	<record>
<!-- Process the MARC in the bib varflds -->			
		<xsl:for-each select="AUTHORITY/IIIRECORD/VARFLD">
			<xsl:choose>
				<xsl:when test="MARCFIXDATA">
					<xsl:element name="controlfield">
						<xsl:attribute name="tag">
							<xsl:value-of select="MARCINFO/MARCTAG" />
						</xsl:attribute>
						<xsl:value-of select="MARCFIXDATA" />
					</xsl:element>
				</xsl:when>                     
				<xsl:when test="MARCINFO">
					<xsl:element name="datafield">
						<xsl:attribute name="tag">
							<xsl:value-of select="MARCINFO/MARCTAG" />
						</xsl:attribute>
						<xsl:attribute name="ind1">
							<xsl:value-of select="MARCINFO/INDICATOR1" />
						</xsl:attribute>
						<xsl:attribute name="ind2">
							<xsl:value-of select="MARCINFO/INDICATOR2" />
						</xsl:attribute>
						<xsl:for-each select="MARCSUBFLD">
							<xsl:element name="subfield">
								<xsl:attribute name="code">
									<xsl:value-of select="SUBFIELDINDICATOR" />
								</xsl:attribute>
								<xsl:value-of select="SUBFIELDDATA" />
							</xsl:element>
						</xsl:for-each>
					</xsl:element>
				</xsl:when>
			</xsl:choose>    
		</xsl:for-each>               				   
	</record>
	
</xsl:template>
</xsl:stylesheet>
