<?xml version="1.0" encoding="UTF-8"?>
<!--
  g-ir-generate 1.86 writes a gir that g-ir-compiler 1.86 rejects.
  Identity copy, then:
    repository version 1.0 becomes 1.2
    void returns keep name none and gain c:type void
    gpointer parameters are name gpointer, not any
    enum members carry c:identifier on the member
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:gi="http://www.gtk.org/introspection/core/1.0"
  xmlns:c="http://www.gtk.org/introspection/c/1.0">

  <xsl:output method="xml" encoding="UTF-8" indent="no"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="gi:repository/@version[.='1.0']">
    <xsl:attribute name="version">1.2</xsl:attribute>
  </xsl:template>

  <xsl:template match="gi:type[@name='none' and not(@c:type)]">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="c:type">void</xsl:attribute>
      <xsl:apply-templates select="node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="gi:type[@name='any']">
    <xsl:element name="type" namespace="http://www.gtk.org/introspection/core/1.0">
      <xsl:attribute name="name">gpointer</xsl:attribute>
      <xsl:attribute name="c:type">gpointer</xsl:attribute>
    </xsl:element>
  </xsl:template>

  <xsl:template match="gi:member[gi:attribute[@name='c:identifier']]">
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="c:identifier">
        <xsl:value-of select="gi:attribute[@name='c:identifier']/@value"/>
      </xsl:attribute>
      <xsl:apply-templates select="node()[not(self::gi:attribute[@name='c:identifier'])]"/>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>
