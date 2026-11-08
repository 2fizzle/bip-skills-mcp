<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8"/>

  <xsl:variable name="csp" select="/DATA_DS/G_1/G_2/G_14"/>

  <!-- Phase-specific filters: hardcoded against ENGLISH PHASE_NAME values.
       In a French tenant these will return empty node-sets and bars render as 0. -->
  <xsl:variable name="draft"   select="$csp[PHASE_NAME='Draft' and EVENT_TYPE_CODE='PHASE_COMPLETION']"/>
  <xsl:variable name="approval" select="$csp[PHASE_NAME='Approval' and EVENT_TYPE_CODE='PHASE_COMPLETION']"/>
  <xsl:variable name="posting" select="$csp[PHASE_NAME='Job formatting' and EVENT_TYPE_CODE='PHASE_COMPLETION']"/>

  <xsl:variable name="avg.draft">
    <xsl:choose>
      <xsl:when test="count($draft)=0">0</xsl:when>
      <xsl:otherwise><xsl:value-of select="sum($draft/STEP_DURATION) div count($draft) div 60"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="avg.approval">
    <xsl:choose>
      <xsl:when test="count($approval)=0">0</xsl:when>
      <xsl:otherwise><xsl:value-of select="sum($approval/STEP_DURATION) div count($approval) div 60"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="avg.posting">
    <xsl:choose>
      <xsl:when test="count($posting)=0">0</xsl:when>
      <xsl:otherwise><xsl:value-of select="sum($posting/STEP_DURATION) div count($posting) div 60"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:template match="/">
    <html><body>
      <h2>Requisition Lifecycle &#183; avg minutes</h2>
      <div class="bar-row">
        <div class="lbl">Draft<span class="n">n=<xsl:value-of select="count($draft)"/></span></div>
        <div class="val"><xsl:value-of select="format-number($avg.draft,'0.0')"/> <span>min</span></div>
      </div>
      <div class="bar-row">
        <div class="lbl">Approval<span class="n">n=<xsl:value-of select="count($approval)"/></span></div>
        <div class="val"><xsl:value-of select="format-number($avg.approval,'0.0')"/> <span>min</span></div>
      </div>
      <div class="bar-row">
        <div class="lbl">Posting<span class="n">n=<xsl:value-of select="count($posting)"/></span></div>
        <div class="val"><xsl:value-of select="format-number($avg.posting,'0.0')"/> <span>min</span></div>
      </div>
    </body></html>
  </xsl:template>
</xsl:stylesheet>
