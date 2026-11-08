<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:date="http://exslt.org/dates-and-times"
                extension-element-prefixes="date">
  <xsl:output method="html" encoding="UTF-8"/>

  <!-- TODO: compute average minutes between CREATION_DATE and APPROVED_DATE across all requisitions.
       We tried date:seconds + date:diff but BI Publisher (xdo11g) throws
       "Undefined function: date:diff" at runtime.
       Needs to work with only core XSLT 1.0 — no EXSLT. -->

  <xsl:variable name="reqs" select="/DATA_DS/G_1[REQUISITION_ID and string-length(CREATION_DATE) &gt;= 19 and string-length(APPROVED_DATE) &gt;= 19]"/>

  <!-- BROKEN — uses EXSLT date: which is unavailable in xdo11g -->
  <xsl:variable name="totalSeconds">
    <xsl:for-each select="$reqs">
      <!-- date:seconds(APPROVED_DATE) - date:seconds(CREATION_DATE) -->
    </xsl:for-each>
  </xsl:variable>

  <xsl:template match="/">
    <html><body>
      <h2>Average Create &#8594; Approve</h2>
      <div class="bar-row">
        <div class="lbl">Create &#8594; Approve<span class="n">n=<xsl:value-of select="count($reqs)"/></span></div>
        <div class="val">?? <span>min</span></div>
      </div>
    </body></html>
  </xsl:template>
</xsl:stylesheet>
