<?xml version="1.0" ?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	
<xsl:output method="text" />
<xsl:strip-space elements="*" />

<xsl:variable name="config">
  <node id="family" type="contents" special="yes" />
  <node id="contents" type="contents" special="yes" />

  <node id="rpc-reply"     ignore="yes" special="yes" />
  <node id="configuration" ignore="yes" special="yes" />
  <node id="version"       ignore="yes" special="yes" />

  <node id="authentication-order" type="list" />
  <node id="events" type="list" />

  <node id="logical-systems" type="explode" extra="yes" />
</xsl:variable>

<xsl:key name="nodeType" match="node" use="@id" />

<!-- match objects with numerous attributes -->
<xsl:template match="*[name or */* or */text()]" priority="-5"><xsl:call-template name="configObject" /></xsl:template>

<!-- match a simple object - value pair -->
<xsl:template match="*" priority="-20">
  <xsl:call-template name="writeIndent" />
  <xsl:value-of select="local-name()" />
  <xsl:if test="text()"><xsl:text> </xsl:text><xsl:call-template name="textValue" /></xsl:if>
  <xsl:text>;&#x0A;</xsl:text>
</xsl:template>

<!-- ignore 'name' tag -->
<xsl:template match="name" />

<!-- simple object with values as child tags -->
<xsl:template match="*[*]" priority="-10">
  <xsl:call-template name="writeIndent" />
  <xsl:value-of select="local-name()" />
  <xsl:for-each select="*">
    <xsl:text> </xsl:text>
    <xsl:choose>
      <xsl:when test="local-name() = 'filename'"><xsl:value-of select="text()" /></xsl:when>
      <xsl:otherwise><xsl:value-of select="local-name()" /></xsl:otherwise>
    </xsl:choose>
  </xsl:for-each>
  <xsl:text>;&#x0A;</xsl:text>
</xsl:template>

<!-- nodes to ignore -->
<xsl:template match="*[key('nodeType',local-name(),$config)/@ignore]">
  <xsl:if test="*"><xsl:apply-templates /></xsl:if>
</xsl:template>

<!-- list nodes that use square brackets -->
<xsl:template match="*[key('nodeType',local-name(),$config)/@type = 'list']">
  <xsl:variable name="nodeName" select="local-name()" />
  <xsl:if test="count(preceding-sibling::*[local-name() = $nodeName]) = 0">
    <xsl:call-template name="writeIndent" />
    <xsl:value-of select="local-name()" />
    <xsl:text> [</xsl:text>  
    <xsl:for-each select="../*[local-name() = $nodeName]">
      <xsl:text> </xsl:text><xsl:value-of select="." />
    </xsl:for-each>
    <xsl:text> ];&#x0A;</xsl:text>
  </xsl:if>
</xsl:template>

<!-- exceptions -->
<!-- family uses child tags as names -->
<xsl:template match="family">
  <xsl:for-each select="*">
    <xsl:call-template name="configObject"><xsl:with-param name="includeParent">1</xsl:with-param></xsl:call-template>
  </xsl:for-each>
</xsl:template>

<!-- contents is a generic wrapper -->
<xsl:template match="contents">
  <xsl:call-template name="writeIndent" />
  <xsl:for-each select="*">
    <xsl:choose>
      <xsl:when test="local-name() = 'name'"><xsl:value-of select="." /></xsl:when>
      <xsl:otherwise><xsl:text> </xsl:text><xsl:value-of select="local-name()" /></xsl:otherwise>
    </xsl:choose>
  </xsl:for-each>
  <xsl:text>;&#x0A;</xsl:text>
</xsl:template>

<!-- interface object has no tag name when in 'interfaces' section -->
<xsl:template match="interfaces/interface">
  <xsl:call-template name="configObject"><xsl:with-param name="skipName">yes</xsl:with-param></xsl:call-template>
</xsl:template>

<!-- exploded objects where the 'name' tag names the child hierarchy -->
<xsl:template match="*[key('nodeType',local-name(),$config)/@type = 'explode']" name="explodedObject">
  <xsl:variable name="nodeName" select="local-name()" />
  <xsl:if test="count(preceding-sibling::*[local-name() = $nodeName]) = 0">
    <xsl:call-template name="writeIndent" />
    <xsl:value-of select="local-name()" /><xsl:text> {&#x0A;</xsl:text>
    <xsl:for-each select="../*[local-name() = $nodeName]">
      <xsl:call-template name="configObject"><xsl:with-param name="skipName">yes</xsl:with-param></xsl:call-template>
    </xsl:for-each>
    <xsl:text>}&#x0A;</xsl:text>
  </xsl:if>
</xsl:template>

<!-- totally non-standard constructs -->
<xsl:template match="member-range">
  <xsl:call-template name="writeIndent" />
  <xsl:text>member-range </xsl:text>
  <xsl:value-of select="name" />
  <xsl:text> to </xsl:text>
  <xsl:value-of select="end-range" />
  <xsl:text>;&#x0A;</xsl:text>
</xsl:template>

<xsl:template match="ieee-802.3ad">
  <xsl:call-template name="writeIndent" />
  <xsl:text>802.3ad </xsl:text><xsl:value-of select="bundle" /><xsl:text>;&#x0A;</xsl:text>
</xsl:template>

<xsl:template match="routing-options/autonomous-system">
  <xsl:call-template name="writeIndent" />
  <xsl:text>autonomous-system </xsl:text><xsl:value-of select="as-number" /><xsl:text>;&#x0A;</xsl:text>
</xsl:template>

<xsl:template match="snmp/community/clients | snmp/trap-group/targets | system/tacplus-server | tacplus/server">
  <xsl:call-template name="explodedObject" />
</xsl:template>

<!-- utility routines -->
<!-- create an object with child objects or attribute-value pairs -->
<xsl:template name="configObject">
  <xsl:param name="includeParent" />
  <xsl:param name="skipName" />
  <xsl:call-template name="writeIndent" />
  <xsl:if test="$includeParent"><xsl:value-of select="local-name(..)" /><xsl:text> </xsl:text></xsl:if>
  <xsl:choose>
    <xsl:when test="$skipName"><xsl:value-of select="name" /></xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="local-name()" />
      <xsl:if test="name|filename"><xsl:text> </xsl:text><xsl:value-of select="name|filename" /></xsl:if>
    </xsl:otherwise>
  </xsl:choose>
  <xsl:choose>
    <xsl:when test="* except (name|filename)">
      <xsl:text> {&#x0A;</xsl:text>
      <xsl:apply-templates />
      <xsl:call-template name="writeIndent" />
      <xsl:text>}</xsl:text>
    </xsl:when>
    <xsl:otherwise>;</xsl:otherwise>
  </xsl:choose>
  <xsl:text>&#x0A;</xsl:text>
</xsl:template>

<!-- create (approximate) whitespace indent -->
<xsl:template name="writeIndent">
  <xsl:if test="key('nodeType',local-name(),$config)/@extra"><xsl:text>    </xsl:text></xsl:if>
  <xsl:for-each select="ancestor::*">
    <xsl:if test="not(key('nodeType',local-name(),$config)/@special)"><xsl:text>    </xsl:text></xsl:if>
    <xsl:if test="key('nodeType',local-name(),$config)/@extra"><xsl:text>    </xsl:text></xsl:if>
  </xsl:for-each>
</xsl:template>

<!-- output quoted text value -->
<xsl:template name="textValue">
  <xsl:choose>
    <xsl:when test="contains(text(),' ')"><xsl:text>&quot;</xsl:text><xsl:value-of select="text()" /><xsl:text>&quot;</xsl:text></xsl:when>
    <xsl:otherwise><xsl:value-of select="text()"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>
