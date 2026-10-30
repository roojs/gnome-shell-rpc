<?xml version="1.0" encoding="UTF-8"?>
<!--
  StrvAgent has no Vala signal. Vala would register a sixth int length.
  This is the stock five-argument initiate signal.
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns="http://www.gtk.org/introspection/core/1.0"
  xmlns:gi="http://www.gtk.org/introspection/core/1.0"
  xmlns:glib="http://www.gtk.org/introspection/glib/1.0"
  xmlns:c="http://www.gtk.org/introspection/c/1.0">

  <xsl:output method="xml" encoding="UTF-8" indent="no"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="gi:class[@name='StrvAgent']">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <glib:signal name="initiate" when="last">
        <return-value transfer-ownership="none">
          <type name="none" c:type="void"/>
        </return-value>
        <parameters>
          <parameter name="action_id" transfer-ownership="none">
            <type name="utf8" c:type="gchar*"/>
          </parameter>
          <parameter name="message" transfer-ownership="none">
            <type name="utf8" c:type="gchar*"/>
          </parameter>
          <parameter name="icon_name" transfer-ownership="none">
            <type name="utf8" c:type="gchar*"/>
          </parameter>
          <parameter name="cookie" transfer-ownership="none">
            <type name="utf8" c:type="gchar*"/>
          </parameter>
          <parameter name="user_names" transfer-ownership="none">
            <array>
              <type name="utf8"/>
            </array>
          </parameter>
        </parameters>
      </glib:signal>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
