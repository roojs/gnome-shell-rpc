<?xml version="1.0" encoding="UTF-8"?>
<!-- Reproduce Clutter-18.typelib naming a method absent from the RPC library. -->
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
    <xsl:attribute name="name">ClutterGestureInvokerBroken</xsl:attribute>
  </xsl:template>

  <xsl:template match="gi:method[@name='get_point_event']/@c:identifier">
    <xsl:attribute name="c:identifier">gsr_clutter_gesture_get_point_event</xsl:attribute>
  </xsl:template>
</xsl:stylesheet>
