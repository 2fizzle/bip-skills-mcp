<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8"/>

  <xsl:key name="reqPhase"
           match="G_14[SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) &gt; 0]"
           use="PHASE_CODE"/>

  <xsl:variable name="csp" select="/DATA_DS/G_1/G_2/G_14"/>
  <xsl:variable name="reqPhases" select="$csp[SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) &gt; 0]"/>
  <xsl:variable name="reqPhases.distinct" select="$reqPhases[count(. | key('reqPhase', PHASE_CODE)[1]) = 1]"/>

  <xsl:template match="/">
    <html><body>
      <h2>Requisition Lifecycle &#183; avg minutes</h2>
      <xsl:choose>
        <xsl:when test="count($reqPhases.distinct) = 0">
          <div class="empty">No data.</div>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="$reqPhases.distinct">
            <xsl:variable name="grp" select="key('reqPhase', PHASE_CODE)"/>
            <div class="bar-row">
              <div class="lbl"><xsl:value-of select="PHASE_NAME"/><span class="n">n=<xsl:value-of select="count($grp)"/></span></div>
              <div class="val"><xsl:value-of select="format-number(sum($grp/STEP_DURATION) div count($grp) div 60, '0.0')"/> <span>min</span></div>
            </div>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </body></html>
  </xsl:template>
</xsl:stylesheet>
