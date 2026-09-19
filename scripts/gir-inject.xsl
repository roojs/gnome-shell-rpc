<?xml version="1.0" encoding="UTF-8"?>
<!--
  Vala 0.56 GirWriter cannot emit nested GStrv or Gio.DesktopAppInfo.
  Identity copy of vala_gir, then:
    class AppSystem — append search.function.gir
    class App get_app_info / app-info — replace from app-info.gir
    class App constructor — drop (not in stock Shell GIR)
-->
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:gi="http://www.gtk.org/introspection/core/1.0">

  <xsl:output method="xml" encoding="UTF-8" indent="no"/>
  <xsl:param name="gstrv"/>
  <xsl:param name="appinfo"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="gi:class[@name='AppSystem']">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
      <xsl:copy-of select="document($gstrv)"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="gi:class[@name='App']/gi:method[@name='get_app_info']">
    <xsl:copy-of select="document($appinfo)//gi:method[@name='get_app_info']"/>
  </xsl:template>

  <xsl:template match="gi:class[@name='App']/gi:property[@name='app-info']">
    <xsl:copy-of select="document($appinfo)//gi:property[@name='app-info']"/>
  </xsl:template>

  <xsl:template match="gi:class[@name='App']/gi:constructor[@name='new']"/>

</xsl:stylesheet>
