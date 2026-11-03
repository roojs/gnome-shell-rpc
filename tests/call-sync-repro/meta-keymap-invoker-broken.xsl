<?xml version="1.0" encoding="UTF-8"?>
<!-- Reproduce Meta-18.typelib naming the stock symbol for an RPC override. -->
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

  <xsl:template match="gi:namespace/@name">
    <xsl:attribute name="name">MetaKeymapInvokerBroken</xsl:attribute>
  </xsl:template>

  <xsl:template
    match="gi:constructor[@name='new_from_rules']/@c:identifier">
    <xsl:attribute name="c:identifier">meta_keymap_description_new_from_rules</xsl:attribute>
  </xsl:template>
</xsl:stylesheet>
