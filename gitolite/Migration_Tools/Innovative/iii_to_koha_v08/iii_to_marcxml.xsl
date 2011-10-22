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
	  <xsl:call-template name="leadergenerator">
	   <xsl:with-param name="biblvl">
	     <xsl:value-of select="BIB/IIIRECORD/TYPEINFO/BIBLIOGRAPHIC/FIXFLD[FIXLABEL = 'BIB LVL']/FIXVALUE" />
     </xsl:with-param>
		</xsl:call-template> 
<!-- Process the MARC in the bib varflds -->			
		<xsl:for-each select="BIB/IIIRECORD/VARFLD">
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
<!-- MARC is processed, now time for bib fixflds to go into 942 field -->             
		<xsl:element name="datafield">
         <xsl:attribute name="tag">942</xsl:attribute>
			<xsl:attribute name="ind1">&#160;</xsl:attribute>
			<xsl:attribute name="ind2">&#160;</xsl:attribute>
			<xsl:element name="subfield">
				<xsl:attribute name="code">2</xsl:attribute>lcc</xsl:element>
			<xsl:element name="subfield">
				<xsl:attribute name="code">#</xsl:attribute>
				<xsl:value-of select="BIB/@number"/>
			</xsl:element>
			<xsl:element name="subfield">
				<xsl:attribute name="code">d</xsl:attribute>
				<xsl:call-template name="dateprocessing">
            		<xsl:with-param name="date">
                		<xsl:value-of select="BIB/IIIRECORD/RECORDINFO/CREATEDATE" />
          			</xsl:with-param>
				</xsl:call-template> 
			</xsl:element>
         	<xsl:for-each select="BIB/IIIRECORD/TYPEINFO/BIBLIOGRAPHIC/FIXFLD">
        		<xsl:call-template name="field942">
            		<xsl:with-param name="biblabel">
                		<xsl:value-of select="FIXLABEL" />
          			</xsl:with-param> 
            		<xsl:with-param name="bibvalue">
                		<xsl:value-of select="FIXVALUE" />
            		</xsl:with-param>
        		</xsl:call-template>     
    		</xsl:for-each>
    		<xsl:for-each select="ITEM">
    			<xsl:element name="subfield">
    				<xsl:attribute name="code">p</xsl:attribute>
    				<xsl:value-of select="IIIRECORD/VARFLD[HEADER/TAG = 'BARCODE']/FIELDDATA"/>
    			</xsl:element>
    		</xsl:for-each>
		</xsl:element>
<!-- Process the MARC in the checkin varflds into MFHD -->
		<xsl:for-each select="CHECKIN[IIIRECORD/VARFLD/MARCINFO]">	
        	<xsl:comment>Start checkin record <xsl:value-of select="@number"/></xsl:comment>		
			<xsl:for-each select="IIIRECORD/VARFLD[MARCINFO]">
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
			</xsl:for-each> 
        	<xsl:comment>End checkin record <xsl:value-of select="@number"/></xsl:comment>
		</xsl:for-each>	 
<!-- item info into the 952 fields, from both fixfld and varfld -->
		<xsl:for-each select="ITEM">
  			<xsl:element name="datafield">
  				<xsl:attribute name="tag">952</xsl:attribute>
				<xsl:attribute name="ind1">&#160;</xsl:attribute>
				<xsl:attribute name="ind2">&#160;</xsl:attribute>
         	<xsl:element name="subfield">
					<xsl:attribute name="code">#</xsl:attribute>
					<xsl:value-of select="@number"/>
				</xsl:element>
         	<xsl:element name="subfield">
					<xsl:attribute name="code">d</xsl:attribute>
					<xsl:call-template name="dateprocessing">
         			<xsl:with-param name="date">
             			<xsl:value-of select="IIIRECORD/RECORDINFO/CREATEDATE" />
       				</xsl:with-param> 
         		</xsl:call-template> 
				</xsl:element>						              
				<xsl:for-each select="IIIRECORD/TYPEINFO/ITEM/FIXFLD">
     				<xsl:call-template name="field952">
         				<xsl:with-param name="itemlabel">
             				<xsl:value-of select="FIXLABEL" />
       					</xsl:with-param> 
         				<xsl:with-param name="itemvalue">
             				<xsl:value-of select="FIXVALUE" />
         				</xsl:with-param>
     				</xsl:call-template>     
    			</xsl:for-each>
				<xsl:for-each select="IIIRECORD/VARFLD">
     				<xsl:call-template name="field952">
         				<xsl:with-param name="itemlabel">
             				<xsl:value-of select="HEADER/TAG" />
       					</xsl:with-param> 
         				<xsl:with-param name="itemvalue">
             				<xsl:value-of select="FIELDDATA" />
         				</xsl:with-param>
     				</xsl:call-template>     
    			</xsl:for-each>
       		<xsl:element name="subfield">
					<xsl:attribute name="code">o</xsl:attribute>
					<xsl:for-each select="../BIB/IIIRECORD/VARFLD[MARCINFO/MARCTAG='090']/MARCSUBFLD">
						<xsl:value-of select="SUBFIELDDATA" /> 
					</xsl:for-each>	
				</xsl:element>
			</xsl:element>		
		</xsl:for-each>
<!-- All done! -->		                				   
	</record>
	
</xsl:template>

<xsl:template name="field942">
	<xsl:param name="biblabel"/>
   <xsl:param name="bibvalue"/>
	<xsl:choose>
		<xsl:when test="$biblabel = 'BCODE3'">
			<xsl:if test="$bibvalue = 'n'">
				<xsl:element name="subfield">
					<xsl:attribute name="code">n</xsl:attribute>1</xsl:element>
			</xsl:if>
		</xsl:when>
		<xsl:when test="$biblabel = 'BIB LVL'">
			<xsl:if test="$bibvalue = 's'">
				<xsl:element name="subfield">
					<xsl:attribute name="code">s</xsl:attribute>1</xsl:element>
			</xsl:if>
		</xsl:when>
	</xsl:choose>
</xsl:template>

<xsl:template name="leadergenerator">
  <xsl:param name="biblvl"/>
  <xsl:element name="leader">
    <xsl:choose>
      <xsl:when test="$biblvl = 'e'">00000cas  2200000la 4500</xsl:when>
      <xsl:otherwise>00000ca<xsl:value-of select="$biblvl"/>  2200000la 4500</xsl:otherwise>
    </xsl:choose>
   </xsl:element> 
</xsl:template>

<!-- You will need to customize this section to match your Millennium codes 
     as well as the mappings between them and their Koha counterparts.  Below
     are some common examples -->
<xsl:template name="field952">
	<xsl:param name="itemlabel"/>
	<xsl:param name="itemvalue"/>
	<xsl:if test="$itemlabel = 'LOC'">
 		<xsl:call-template name="locationdetangler">
     		<xsl:with-param name="locationcode" select="normalize-space($itemvalue)" />
     	</xsl:call-template>    
 	</xsl:if>        
	<xsl:choose>
		<xsl:when test="$itemlabel = 'BARCODE'">
        	<xsl:if test="not($itemvalue = 'do not')">
				<xsl:element name="subfield">
					<xsl:attribute name="code">p</xsl:attribute>
					<xsl:value-of select="$itemvalue" />  
				</xsl:element>
            </xsl:if>    
		</xsl:when>    
		<xsl:when test="$itemlabel = 'PRICE'">
			<xsl:if test="$itemvalue != '$0.00'">  
				<xsl:element name="subfield">  
					<xsl:attribute name="code">g</xsl:attribute>
					<xsl:value-of select="$itemvalue" />   
				</xsl:element>   
			</xsl:if>
		</xsl:when>    
		<xsl:when test="$itemlabel = 'LOUTDATE'">   
			<xsl:element name="subfield">
				<xsl:attribute name="code">s</xsl:attribute>
				<xsl:call-template name="dateprocessing">
            				<xsl:with-param name="date">
                				<xsl:value-of select="$itemvalue" />
          				</xsl:with-param> 
            			</xsl:call-template>  
			</xsl:element>   
		</xsl:when>    
		<xsl:when test="$itemlabel = 'STATUS'">
			<xsl:choose>
				<xsl:when test="$itemvalue = 'o'">
					<xsl:element name="subfield">
						<xsl:attribute name="code">7</xsl:attribute>1</xsl:element>  
				</xsl:when>
				<xsl:when test="$itemvalue = 'i'">
          <xsl:element name="subfield">
 				 <xsl:attribute name="code">7</xsl:attribute>2</xsl:element>
 				 </xsl:when>
				<xsl:when test="$itemvalue = 's'">
					<xsl:element name="subfield">
						<xsl:attribute name="code">1</xsl:attribute>1</xsl:element>  
				</xsl:when>
				<xsl:when test="$itemvalue = 'm'">
					<xsl:element name="subfield">
						<xsl:attribute name="code">1</xsl:attribute>2</xsl:element>  
				</xsl:when>
				<xsl:when test="$itemvalue = 'd'">
					<xsl:element name="subfield">
						<xsl:attribute name="code">1</xsl:attribute>3</xsl:element>  
				</xsl:when>
				<xsl:when test="$itemvalue = 'e'">
					<xsl:element name="subfield">
						<xsl:attribute name="code">1</xsl:attribute>4</xsl:element>  
				</xsl:when> 		                	    
				<xsl:when test="$itemvalue = 'n'">
					<xsl:element name="subfield">
						<xsl:attribute name="code">1</xsl:attribute>5</xsl:element>  
				</xsl:when>
				<xsl:when test="$itemvalue = 'z'">
					<xsl:element name="subfield">
						<xsl:attribute name="code">1</xsl:attribute>6</xsl:element>  
				</xsl:when>  
				<xsl:when test="$itemvalue = 'v'">
					<xsl:element name="subfield">
						<xsl:attribute name="code">1</xsl:attribute>12</xsl:element>  
				</xsl:when> 
			</xsl:choose>
		</xsl:when>	
    <xsl:when test="$itemlabel = 'VENDOR'"> 
			<xsl:element name="subfield">       
				<xsl:attribute name="code">e</xsl:attribute>
				<xsl:value-of select="$itemvalue" />
			</xsl:element>  
		</xsl:when>	
		<xsl:when test="$itemlabel = 'CALL#'"> 
			<xsl:element name="subfield">       
				<xsl:attribute name="code">o</xsl:attribute>
				<xsl:value-of select="$itemvalue" />
			</xsl:element>  
		</xsl:when>
		<xsl:when test="$itemlabel = 'TOT CHKOUT'">
			<xsl:element name="subfield">
				<xsl:attribute name="code">l</xsl:attribute>
				<xsl:value-of select="$itemvalue" />
			</xsl:element>  
		</xsl:when>   
		<xsl:when test="$itemlabel = 'TOT RENEW'">
			<xsl:element name="subfield">
				<xsl:attribute name="code">m</xsl:attribute>
				<xsl:value-of select="$itemvalue" />
			</xsl:element>  
		</xsl:when>    
		<xsl:when test="$itemlabel = 'VOL'">
			<xsl:element name="subfield">
				<xsl:attribute name="code">h</xsl:attribute>
				<xsl:value-of select="$itemvalue" />
			</xsl:element>  
		</xsl:when>
		<xsl:when test="$itemlabel = 'COPY #'">
			<xsl:if test="$itemvalue > 1">
				<xsl:element name="subfield">				
					<xsl:attribute name="code">t</xsl:attribute>
					<xsl:value-of select="$itemvalue" />
				</xsl:element>	  
			</xsl:if>			
		</xsl:when>  
		<xsl:when test="$itemlabel = 'MESSAGE'">
			<xsl:element name="subfield">
				<xsl:attribute name="code">z</xsl:attribute>
				<xsl:value-of select="$itemvalue" />
			</xsl:element>  
		</xsl:when>
		<xsl:when test="$itemlabel = 'DONOR'">
			<xsl:element name="subfield">
				<xsl:attribute name="code">z</xsl:attribute>
				<xsl:value-of select="$itemvalue" />
			</xsl:element>  
		</xsl:when>
      		<xsl:when test="$itemlabel = 'I TYPE'">  
			<xsl:element name="subfield">
				<xsl:attribute name="code">8</xsl:attribute>
				<xsl:choose>
					<xsl:when test="$itemvalue = 0">JOUR</xsl:when>
					<xsl:when test="$itemvalue = 1">BOOK</xsl:when>
					<xsl:when test="$itemvalue = 2">VHS</xsl:when>
					<xsl:when test="$itemvalue = 3">CAS</xsl:when>
					<xsl:when test="$itemvalue = 4">SLIDE</xsl:when>
					<xsl:when test="$itemvalue = 6">ROM</xsl:when>
					<xsl:when test="$itemvalue = 10">LAP</xsl:when>
					<xsl:when test="$itemvalue = 11">EQ</xsl:when>
					<xsl:otherwise>UNK</xsl:otherwise>
				</xsl:choose>        							
			</xsl:element>  
      		</xsl:when>               	               
	</xsl:choose>                  
</xsl:template>

<xsl:template name="dateprocessing">
	<xsl:param name="date"/>
	<xsl:choose>
		<xsl:when test="contains($date, '-9')">	
			<xsl:variable name='date2a' select="substring($date, 1,5)"/>
			<xsl:variable name='date2b' select="substring($date, 7,8)"/>
			<xsl:variable name='date2' select="concat('19', $date2b, '-', $date2a)"/>
			<xsl:value-of select="$date2" />
		</xsl:when>
		<xsl:when test="$date = '  -  -  '"></xsl:when>
		<xsl:otherwise>
			<xsl:variable name='date3a' select="substring($date, 1, 5)"/>
			<xsl:variable name='date3b' select="substring($date, 7, 4)"/>
			<xsl:variable name='date3' select="concat($date3b, '-', $date3a)"/>	
			<xsl:value-of select="$date3"/>
		</xsl:otherwise>
	</xsl:choose>
</xsl:template>
    
</xsl:stylesheet>
