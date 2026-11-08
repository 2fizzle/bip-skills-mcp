<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8"/>
  
  <!-- Keys accept either nested G_14 (requisition extract) OR root-level G_1
       (standalone CSP history extract — distinguishable by HISTORY_EVENT_ID). -->
  <xsl:key name="cspMonth"
           match="G_14 | G_1[HISTORY_EVENT_ID]"
           use="substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE),1,7)"/>
  <xsl:key name="reqPhaseComp"
           match="G_14[SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) &gt; 0]
                | G_1[HISTORY_EVENT_ID and SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) &gt; 0]"
           use="PHASE_CODE"/>
  <xsl:key name="cndPhaseComp"
           match="G_14[SOURCE_OBJECT_ID='4' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) &gt; 0]
                | G_1[HISTORY_EVENT_ID and SOURCE_OBJECT_ID='4' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) &gt; 0]"
           use="PHASE_CODE"/>

  <!-- Requisition-level phase distribution (from G_1), used as fallback when
       the data model carries no req-side PHASE_COMPLETION events in G_14. -->
  <xsl:key name="reqGroupByPhase"
           match="/DATA_DS/G_1[REQUISITION_ID and string-length(PHASE_CODE) &gt; 0]"
           use="PHASE_CODE"/>

  <xsl:variable name="clr.primary"  select="'#3200EB'"/>
  <xsl:variable name="clr.primary2" select="'#5F3BFF'"/>
  <xsl:variable name="clr.primary3" select="'#8B5CF6'"/>
  <xsl:variable name="clr.accent"   select="'#EA580C'"/>
  <xsl:variable name="clr.ok"       select="'#10B981'"/>
  <xsl:variable name="clr.warn"     select="'#F59E0B'"/>
  <xsl:variable name="clr.bad"      select="'#EF4444'"/>
  <xsl:variable name="clr.ink"      select="'#0F172A'"/>
  <xsl:variable name="clr.mute"     select="'#64748B'"/>
  <xsl:variable name="clr.line"     select="'#E2E8F0'"/>
  <xsl:variable name="clr.bg"       select="'#F4F5FA'"/>

  <!-- Accept both extract shapes: nested G_14 (requisitions) or root-level G_1 (standalone CSP history). -->
  <xsl:variable name="csp"       select="/DATA_DS/G_1/G_2/G_14 | /DATA_DS/G_1[HISTORY_EVENT_ID]"/>
  <xsl:variable name="total"     select="count($csp)"/>
  <xsl:variable name="phaseComp" select="count($csp[EVENT_TYPE_CODE='PHASE_COMPLETION'])"/>
  <xsl:variable name="stateComp" select="count($csp[EVENT_TYPE_CODE='STATE_COMPLETION'])"/>
  <xsl:variable name="backward"  select="count($csp[EVENT_TYPE_CODE='RETURN_TO_PRIOR_PHASE' or EVENT_IS_BACKWARD='Y'])"/>
  <xsl:variable name="auto"      select="count($csp[EVENT_TYPE_CODE='AUTO_ACTION'])"/>
  <xsl:variable name="recruiters" select="count($csp/TRANSITION_BY[not(.=preceding::TRANSITION_BY)])"/>
  <xsl:variable name="backward.rate">
    <xsl:choose>
      <xsl:when test="($phaseComp + $backward)=0">0</xsl:when>
      <xsl:otherwise><xsl:value-of select="$backward div ($phaseComp + $backward)"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="tone.rework">
    <xsl:choose>
      <xsl:when test="$backward.rate &gt; 0.15"><xsl:value-of select="$clr.bad"/></xsl:when>
      <xsl:when test="$backward.rate &gt; 0.05"><xsl:value-of select="$clr.warn"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$clr.ok"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- Dynamic per-phase discovery (locale-independent, uses PHASE_CODE).
       PHASE_NAME is carried for display so labels render in the user's locale. -->
  <xsl:variable name="req.phases"          select="$csp[SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) &gt; 0]"/>
  <xsl:variable name="req.phases.distinct" select="$req.phases[count(. | key('reqPhaseComp', PHASE_CODE)[1]) = 1]"/>
  <xsl:variable name="cnd.phases"          select="$csp[SOURCE_OBJECT_ID='4' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) &gt; 0]"/>
  <xsl:variable name="cnd.phases.distinct" select="$cnd.phases[count(. | key('cndPhaseComp', PHASE_CODE)[1]) = 1]"/>

  <!-- Fallback universe: requisitions themselves (root G_1), grouped by current PHASE_CODE. -->
  <xsl:variable name="allReqs"                 select="/DATA_DS/G_1[REQUISITION_ID and string-length(PHASE_CODE) &gt; 0]"/>
  <xsl:variable name="allReqs.byPhase.distinct" select="$allReqs[count(. | key('reqGroupByPhase', PHASE_CODE)[1]) = 1]"/>

  <!-- Date-diff (in minutes) cohorts: subsets of reqs that have both endpoints populated.
       Approximate minutes-since-epoch = year*525600 + month*43830 + day*1440 + hour*60 + minute + sec/60
       (good enough for cycle-time bars — diffs are typically same-day to a few days). -->
  <xsl:variable name="reqs.creToApp" select="/DATA_DS/G_1[REQUISITION_ID and string-length(CREATION_DATE) &gt;= 19 and string-length(APPROVED_DATE) &gt;= 19]"/>
  <xsl:variable name="reqs.appToOpn" select="/DATA_DS/G_1[REQUISITION_ID and string-length(APPROVED_DATE) &gt;= 19 and string-length(OPEN_DATE) &gt;= 19]"/>
  <xsl:variable name="reqs.opnToInt" select="/DATA_DS/G_1[REQUISITION_ID and string-length(OPEN_DATE) &gt;= 19 and string-length(INT_FIRST_POSTED_DATE) &gt;= 19]"/>
  <xsl:variable name="reqs.opnToExt" select="/DATA_DS/G_1[REQUISITION_ID and string-length(OPEN_DATE) &gt;= 19 and string-length(EXT_FIRST_POSTED_DATE) &gt;= 19]"/>
  <xsl:variable name="hasReqDates" select="count($reqs.creToApp) + count($reqs.appToOpn) + count($reqs.opnToInt) + count($reqs.opnToExt)"/>

  <!-- Aggregate durations in minutes — computed via recursive named templates
       (XSLT 1.0 has no native date arithmetic). -->
  <xsl:variable name="sum.creToApp.min">
    <xsl:call-template name="sum-diff-min">
      <xsl:with-param name="nodes" select="$reqs.creToApp"/>
      <xsl:with-param name="mode"  select="'creToApp'"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="sum.appToOpn.min">
    <xsl:call-template name="sum-diff-min">
      <xsl:with-param name="nodes" select="$reqs.appToOpn"/>
      <xsl:with-param name="mode"  select="'appToOpn'"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="sum.opnToInt.min">
    <xsl:call-template name="sum-diff-min">
      <xsl:with-param name="nodes" select="$reqs.opnToInt"/>
      <xsl:with-param name="mode"  select="'opnToInt'"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="sum.opnToExt.min">
    <xsl:call-template name="sum-diff-min">
      <xsl:with-param name="nodes" select="$reqs.opnToExt"/>
      <xsl:with-param name="mode"  select="'opnToExt'"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:variable name="avg.creToApp.min">
    <xsl:choose>
      <xsl:when test="count($reqs.creToApp) = 0">0</xsl:when>
      <xsl:otherwise><xsl:value-of select="number($sum.creToApp.min) div count($reqs.creToApp)"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="avg.appToOpn.min">
    <xsl:choose>
      <xsl:when test="count($reqs.appToOpn) = 0">0</xsl:when>
      <xsl:otherwise><xsl:value-of select="number($sum.appToOpn.min) div count($reqs.appToOpn)"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="avg.opnToInt.min">
    <xsl:choose>
      <xsl:when test="count($reqs.opnToInt) = 0">0</xsl:when>
      <xsl:otherwise><xsl:value-of select="number($sum.opnToInt.min) div count($reqs.opnToInt)"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="avg.opnToExt.min">
    <xsl:choose>
      <xsl:when test="count($reqs.opnToExt) = 0">0</xsl:when>
      <xsl:otherwise><xsl:value-of select="number($sum.opnToExt.min) div count($reqs.opnToExt)"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- Max of the 4 avg values — used as bar/column scale. -->
  <xsl:variable name="max.req.dates.min">
    <xsl:choose>
      <xsl:when test="number($avg.creToApp.min) &gt;= number($avg.appToOpn.min)
                  and number($avg.creToApp.min) &gt;= number($avg.opnToInt.min)
                  and number($avg.creToApp.min) &gt;= number($avg.opnToExt.min)"><xsl:value-of select="$avg.creToApp.min"/></xsl:when>
      <xsl:when test="number($avg.appToOpn.min) &gt;= number($avg.opnToInt.min)
                  and number($avg.appToOpn.min) &gt;= number($avg.opnToExt.min)"><xsl:value-of select="$avg.appToOpn.min"/></xsl:when>
      <xsl:when test="number($avg.opnToInt.min) &gt;= number($avg.opnToExt.min)"><xsl:value-of select="$avg.opnToInt.min"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$avg.opnToExt.min"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="max.reqMix">
    <xsl:choose>
      <xsl:when test="count($allReqs.byPhase.distinct) = 0">0</xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$allReqs.byPhase.distinct">
          <xsl:sort select="count(key('reqGroupByPhase', PHASE_CODE))" data-type="number" order="descending"/>
          <xsl:if test="position()=1"><xsl:value-of select="count(key('reqGroupByPhase', PHASE_CODE))"/></xsl:if>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="max.req.min">
    <xsl:choose>
      <xsl:when test="count($req.phases.distinct) = 0">0</xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$req.phases.distinct">
          <xsl:sort select="sum(key('reqPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('reqPhaseComp', PHASE_CODE)) div 60" data-type="number" order="descending"/>
          <xsl:if test="position()=1">
            <xsl:value-of select="sum(key('reqPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('reqPhaseComp', PHASE_CODE)) div 60"/>
          </xsl:if>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>
  <xsl:variable name="max.cnd.hr">
    <xsl:choose>
      <xsl:when test="count($cnd.phases.distinct) = 0">0</xsl:when>
      <xsl:otherwise>
        <xsl:for-each select="$cnd.phases.distinct">
          <xsl:sort select="sum(key('cndPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('cndPhaseComp', PHASE_CODE)) div 3600" data-type="number" order="descending"/>
          <xsl:if test="position()=1">
            <xsl:value-of select="sum(key('cndPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('cndPhaseComp', PHASE_CODE)) div 3600"/>
          </xsl:if>
        </xsl:for-each>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <xsl:variable name="pct.phase">
    <xsl:choose><xsl:when test="$total=0">0</xsl:when><xsl:otherwise><xsl:value-of select="($phaseComp * 100) div $total"/></xsl:otherwise></xsl:choose>
  </xsl:variable>
  <xsl:variable name="pct.state">
    <xsl:choose><xsl:when test="$total=0">0</xsl:when><xsl:otherwise><xsl:value-of select="($stateComp * 100) div $total"/></xsl:otherwise></xsl:choose>
  </xsl:variable>
  <xsl:variable name="pct.auto">
    <xsl:choose><xsl:when test="$total=0">0</xsl:when><xsl:otherwise><xsl:value-of select="($auto * 100) div $total"/></xsl:otherwise></xsl:choose>
  </xsl:variable>
  <xsl:variable name="pct.back">
    <xsl:choose><xsl:when test="$total=0">0</xsl:when><xsl:otherwise><xsl:value-of select="($backward * 100) div $total"/></xsl:otherwise></xsl:choose>
  </xsl:variable>

  <xsl:variable name="months" select="$csp[(EVENT_OCCURRED_DATE or TRANSITION_DATE) and generate-id() = generate-id(key('cspMonth', substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE),1,7))[1])]"/>

  <xsl:template match="/">
    <html>
      <head>
        <title>IRC CSP Process Analytics</title>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
        <style type="text/css">
body{margin:0;padding:0;font-family:"Segoe UI","Helvetica Neue",Helvetica,Arial,sans-serif;background:#F4F5FA;color:#0F172A;font-size:14px;line-height:1.45;}
.wrap{max-width:1280px;margin:0 auto;background:#F4F5FA;}
.hero{display:table;width:calc(100% - 44px);background:#FFFFFF;border:1px solid #E2E8F0;border-radius:8px;margin:10px 22px 14px 22px;padding:16px 22px;box-sizing:border-box;border-collapse:separate;}
.hero .copy{display:table-cell;vertical-align:middle;padding-left:24px;}
.hero h1{margin:0;font-size:26px;font-weight:700;color:#1D4ED8;letter-spacing:-0.3px;}
.hero .sub{margin-top:4px;font-size:13px;color:#64748B;}
.hero .meta{display:table-cell;vertical-align:middle;text-align:right;font-size:12px;color:#64748B;padding-left:24px;white-space:nowrap;}
.hero .meta b{color:#0F172A;}
.kpi-row{padding:14px 22px 0 22px;font-size:0;}
.card{display:inline-block;vertical-align:top;width:24%;margin-right:1.33%;background:#FFFFFF;border:1px solid #E2E8F0;border-radius:6px;padding:14px 14px 14px 16px;box-sizing:border-box;position:relative;overflow:hidden;font-size:13px;}
.card.last{margin-right:0;}
.card .accent{position:absolute;left:0;top:0;bottom:0;width:4px;}
.card .label{font-size:10px;text-transform:uppercase;letter-spacing:.6px;color:#64748B;font-weight:600;}
.card .value{font-size:28px;font-weight:700;color:#0F172A;line-height:1.1;margin-top:6px;}
.card .sub{font-size:11px;color:#64748B;margin-top:6px;}
.two-col{padding:14px 22px 0 22px;font-size:0;}
.panel{display:inline-block;vertical-align:top;width:49%;margin-right:1.8%;background:#FFFFFF;border:1px solid #E2E8F0;border-radius:6px;padding:14px 16px 18px 16px;box-sizing:border-box;font-size:13px;}
.panel.last{margin-right:0;}
.panel h2{margin:0;font-size:11px;font-weight:700;color:#0F172A;text-transform:uppercase;letter-spacing:0.06em;}
.panel .hint{font-size:12px;color:#64748B;font-style:italic;margin:4px 0 12px 0;}
.donut-wrap{font-size:0;}
.donut-wrap .svg-col{display:inline-block;vertical-align:middle;width:45%;}
.donut-wrap .lg-col{display:inline-block;vertical-align:middle;width:55%;font-size:12px;}
.legend-row{display:table;width:100%;margin-bottom:6px;}
.legend-row .sw{display:table-cell;width:14px;vertical-align:middle;}
.legend-row .sw i{display:inline-block;width:10px;height:10px;border-radius:2px;}
.legend-row .lb{display:table-cell;vertical-align:middle;padding-left:6px;color:#0F172A;}
.legend-row .vn{display:table-cell;width:60px;vertical-align:middle;text-align:right;font-weight:700;color:#0F172A;}
.legend-row .vp{display:table-cell;width:50px;vertical-align:middle;text-align:right;color:#64748B;font-size:11px;}
.heat-grid{font-size:0;}
.heat-cell{display:inline-block;vertical-align:top;width:14%;margin-right:1.5%;margin-bottom:8px;padding:10px 8px;border-radius:6px;box-sizing:border-box;font-size:12px;color:#FFFFFF;text-align:center;}
.heat-cell.last{margin-right:0;}
.heat-cell .m{font-size:10px;opacity:.85;}
.heat-cell .v{font-size:18px;font-weight:700;line-height:1.1;}
.heat-legend{font-size:11px;color:#64748B;margin-top:6px;}
.bar-row{display:table;width:100%;margin-bottom:8px;}
.bar-row .lbl{display:table-cell;width:34%;vertical-align:middle;padding-right:8px;font-size:12px;}
.bar-row .lbl .n{display:block;font-size:10px;color:#64748B;margin-top:1px;}
.bar-row .track{display:table-cell;vertical-align:middle;}
.bar-row .track .wrap{background:#F4F5FA;height:12px;border-radius:3px;overflow:hidden;}
.bar-row .track .fill{height:12px;border-radius:3px;}
.bar-row .val{display:table-cell;width:70px;vertical-align:middle;text-align:right;padding-left:8px;font-size:12px;font-weight:700;}
.bar-row .val span{font-size:10px;font-weight:400;color:#64748B;}
.section{background:#FFFFFF;border:1px solid #E2E8F0;border-radius:8px;margin:14px 22px 14px 22px;padding:18px 22px;}
.section h2{margin:0 0 14px 0;font-size:18px;font-weight:700;color:#1D4ED8;letter-spacing:-0.2px;}
table.etype{width:100%;border-collapse:collapse;font-size:12.5px;}
table.etype th{background:#F4F5FA;color:#64748B;font-weight:600;font-size:11px;text-transform:uppercase;letter-spacing:.5px;text-align:left;padding:8px 10px;}
table.etype th.num,table.etype td.num{text-align:right;}
table.etype td{padding:9px 10px;border-top:1px solid #E2E8F0;color:#0F172A;vertical-align:middle;}
table.etype td .wrap{background:#F4F5FA;height:10px;border-radius:3px;}
table.etype td .fill{height:10px;border-radius:3px;}
.footer{padding:10px 22px 16px 22px;font-size:11px;color:#64748B;text-align:center;border-top:1px solid #E2E8F0;}
        </style>
      </head>
      <body>
        <div class="wrap">

          <div class="hero">
            <div class="copy">
              <h1>CSP Process Analytics</h1>
              <div class="sub">Candidate Selection Process &#183; Phase &amp; State transitions &#183; Bottlenecks &amp; rework</div>
            </div>
            <div class="meta">
              <div>IRC Recruiting Dashboard</div>
              <div>Events: <b><xsl:value-of select="$total"/></b> &#183; Phase: <b><xsl:value-of select="$phaseComp"/></b> &#183; Backward: <b><xsl:value-of select="$backward"/></b></div>
            </div>
          </div>

          <div class="kpi-row">
            <xsl:call-template name="kpi">
              <xsl:with-param name="label">Total CSP Events</xsl:with-param>
              <xsl:with-param name="value" select="$total"/>
              <xsl:with-param name="sub">phase &amp; state transitions</xsl:with-param>
              <xsl:with-param name="color" select="$clr.primary"/>
              <xsl:with-param name="last">0</xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="kpi">
              <xsl:with-param name="label">Phase Completions</xsl:with-param>
              <xsl:with-param name="value" select="$phaseComp"/>
              <xsl:with-param name="sub">states: <xsl:value-of select="$stateComp"/></xsl:with-param>
              <xsl:with-param name="color" select="$clr.ok"/>
              <xsl:with-param name="last">0</xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="kpi">
              <xsl:with-param name="label">Backward Movements</xsl:with-param>
              <xsl:with-param name="value" select="$backward"/>
              <xsl:with-param name="sub">rework rate <xsl:value-of select="format-number($backward.rate,'0.0%')"/></xsl:with-param>
              <xsl:with-param name="color" select="$tone.rework"/>
              <xsl:with-param name="last">0</xsl:with-param>
            </xsl:call-template>
            <xsl:call-template name="kpi">
              <xsl:with-param name="label">Active Recruiters</xsl:with-param>
              <xsl:with-param name="value" select="$recruiters"/>
              <xsl:with-param name="sub">distinct actors in CSP</xsl:with-param>
              <xsl:with-param name="color" select="$clr.accent"/>
              <xsl:with-param name="last">1</xsl:with-param>
            </xsl:call-template>
          </div>

          <div class="two-col">
            <div class="panel">
              <xsl:choose>
                <xsl:when test="count($req.phases.distinct) &gt; 0">
                  <h2>Requisition Lifecycle &#183; avg minutes</h2>
                  <div class="hint">SOURCE_OBJECT_ID = 1 &#183; PHASE_COMPLETION events &#183; phases discovered dynamically</div>
                </xsl:when>
                <xsl:when test="$hasReqDates &gt; 0">
                  <h2>Requisition Lifecycle &#183; avg minutes (cycle time)</h2>
                  <div class="hint">Derived from G_1 date milestones: Creation &#8594; Approved &#8594; Open &#8594; First posted (internal / external)</div>
                </xsl:when>
                <xsl:when test="count($allReqs.byPhase.distinct) &gt; 0">
                  <h2>Requisition Mix &#183; current phase</h2>
                  <div class="hint">No req-side PHASE_COMPLETION events in this extract &#8212; showing requisition count per phase (G_1/PHASE_NAME)</div>
                </xsl:when>
                <xsl:otherwise>
                  <h2>Requisition Lifecycle</h2>
                  <div class="hint">No requisition-side data available in the current extract.</div>
                </xsl:otherwise>
              </xsl:choose>
              <xsl:choose>
                <xsl:when test="count($req.phases.distinct) = 0 and $hasReqDates = 0 and count($allReqs.byPhase.distinct) = 0">
                  <!-- nothing to render -->
                </xsl:when>
                <xsl:when test="count($req.phases.distinct) = 0 and $hasReqDates &gt; 0">
                  <!-- Cycle-time bars derived from G_1 ISO date milestones. -->
                  <xsl:if test="count($reqs.creToApp) &gt; 0">
                    <xsl:call-template name="bar">
                      <xsl:with-param name="label">Create &#8594; Approve</xsl:with-param>
                      <xsl:with-param name="val"   select="number($avg.creToApp.min)"/>
                      <xsl:with-param name="max"   select="number($max.req.dates.min)"/>
                      <xsl:with-param name="n"     select="count($reqs.creToApp)"/>
                      <xsl:with-param name="unit">min</xsl:with-param>
                      <xsl:with-param name="color" select="$clr.primary"/>
                    </xsl:call-template>
                  </xsl:if>
                  <xsl:if test="count($reqs.appToOpn) &gt; 0">
                    <xsl:call-template name="bar">
                      <xsl:with-param name="label">Approve &#8594; Open</xsl:with-param>
                      <xsl:with-param name="val"   select="number($avg.appToOpn.min)"/>
                      <xsl:with-param name="max"   select="number($max.req.dates.min)"/>
                      <xsl:with-param name="n"     select="count($reqs.appToOpn)"/>
                      <xsl:with-param name="unit">min</xsl:with-param>
                      <xsl:with-param name="color" select="$clr.primary2"/>
                    </xsl:call-template>
                  </xsl:if>
                  <xsl:if test="count($reqs.opnToInt) &gt; 0">
                    <xsl:call-template name="bar">
                      <xsl:with-param name="label">Open &#8594; Post (Int)</xsl:with-param>
                      <xsl:with-param name="val"   select="number($avg.opnToInt.min)"/>
                      <xsl:with-param name="max"   select="number($max.req.dates.min)"/>
                      <xsl:with-param name="n"     select="count($reqs.opnToInt)"/>
                      <xsl:with-param name="unit">min</xsl:with-param>
                      <xsl:with-param name="color" select="$clr.accent"/>
                    </xsl:call-template>
                  </xsl:if>
                  <xsl:if test="count($reqs.opnToExt) &gt; 0">
                    <xsl:call-template name="bar">
                      <xsl:with-param name="label">Open &#8594; Post (Ext)</xsl:with-param>
                      <xsl:with-param name="val"   select="number($avg.opnToExt.min)"/>
                      <xsl:with-param name="max"   select="number($max.req.dates.min)"/>
                      <xsl:with-param name="n"     select="count($reqs.opnToExt)"/>
                      <xsl:with-param name="unit">min</xsl:with-param>
                      <xsl:with-param name="color" select="$clr.ok"/>
                    </xsl:call-template>
                  </xsl:if>
                </xsl:when>
                <xsl:when test="count($req.phases.distinct) = 0">
                  <xsl:for-each select="$allReqs.byPhase.distinct">
                    <xsl:sort select="count(key('reqGroupByPhase', PHASE_CODE))" data-type="number" order="descending"/>
                    <xsl:variable name="grp" select="key('reqGroupByPhase', PHASE_CODE)"/>
                    <xsl:variable name="n" select="count($grp)"/>
                    <xsl:variable name="label">
                      <xsl:choose>
                        <xsl:when test="string-length(PHASE_NAME) &gt; 0"><xsl:value-of select="PHASE_NAME"/></xsl:when>
                        <xsl:otherwise><xsl:value-of select="PHASE_CODE"/></xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="color">
                      <xsl:choose>
                        <xsl:when test="position() mod 5 = 1"><xsl:value-of select="$clr.primary"/></xsl:when>
                        <xsl:when test="position() mod 5 = 2"><xsl:value-of select="$clr.primary2"/></xsl:when>
                        <xsl:when test="position() mod 5 = 3"><xsl:value-of select="$clr.accent"/></xsl:when>
                        <xsl:when test="position() mod 5 = 4"><xsl:value-of select="$clr.ok"/></xsl:when>
                        <xsl:otherwise><xsl:value-of select="$clr.primary3"/></xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:call-template name="bar">
                      <xsl:with-param name="label" select="$label"/>
                      <xsl:with-param name="val"   select="$n"/>
                      <xsl:with-param name="max"   select="$max.reqMix"/>
                      <xsl:with-param name="n"     select="$n"/>
                      <xsl:with-param name="unit">reqs</xsl:with-param>
                      <xsl:with-param name="color" select="$color"/>
                    </xsl:call-template>
                  </xsl:for-each>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:for-each select="$req.phases.distinct">
                    <xsl:sort select="sum(key('reqPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('reqPhaseComp', PHASE_CODE)) div 60" data-type="number" order="descending"/>
                    <xsl:variable name="grp" select="key('reqPhaseComp', PHASE_CODE)"/>
                    <xsl:variable name="n" select="count($grp)"/>
                    <xsl:variable name="avgMin" select="sum($grp/STEP_DURATION) div $n div 60"/>
                    <xsl:variable name="label">
                      <xsl:choose>
                        <xsl:when test="string-length(PHASE_NAME) &gt; 0"><xsl:value-of select="PHASE_NAME"/></xsl:when>
                        <xsl:otherwise><xsl:value-of select="PHASE_CODE"/></xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="color">
                      <xsl:choose>
                        <xsl:when test="position() mod 5 = 1"><xsl:value-of select="$clr.primary"/></xsl:when>
                        <xsl:when test="position() mod 5 = 2"><xsl:value-of select="$clr.primary2"/></xsl:when>
                        <xsl:when test="position() mod 5 = 3"><xsl:value-of select="$clr.accent"/></xsl:when>
                        <xsl:when test="position() mod 5 = 4"><xsl:value-of select="$clr.ok"/></xsl:when>
                        <xsl:otherwise><xsl:value-of select="$clr.primary3"/></xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:call-template name="bar">
                      <xsl:with-param name="label" select="$label"/>
                      <xsl:with-param name="val"   select="$avgMin"/>
                      <xsl:with-param name="max"   select="$max.req.min"/>
                      <xsl:with-param name="n"     select="$n"/>
                      <xsl:with-param name="unit">min</xsl:with-param>
                      <xsl:with-param name="color" select="$color"/>
                    </xsl:call-template>
                  </xsl:for-each>
                </xsl:otherwise>
              </xsl:choose>
            </div>
            <div class="panel last">
              <h2>Candidate Journey &#183; avg hours</h2>
              <div class="hint">SOURCE_OBJECT_ID = 4 &#183; PHASE_COMPLETION events &#183; phases discovered dynamically</div>
              <xsl:choose>
                <xsl:when test="count($cnd.phases.distinct) = 0">
                  <div class="hint">No candidate-side PHASE_COMPLETION events in the current CSP extract.</div>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:for-each select="$cnd.phases.distinct">
                    <xsl:sort select="sum(key('cndPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('cndPhaseComp', PHASE_CODE)) div 3600" data-type="number" order="descending"/>
                    <xsl:variable name="grp" select="key('cndPhaseComp', PHASE_CODE)"/>
                    <xsl:variable name="n" select="count($grp)"/>
                    <xsl:variable name="avgHr" select="sum($grp/STEP_DURATION) div $n div 3600"/>
                    <xsl:variable name="label">
                      <xsl:choose>
                        <xsl:when test="string-length(PHASE_NAME) &gt; 0"><xsl:value-of select="PHASE_NAME"/></xsl:when>
                        <xsl:otherwise><xsl:value-of select="PHASE_CODE"/></xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:variable name="color">
                      <xsl:choose>
                        <xsl:when test="position() mod 5 = 1"><xsl:value-of select="$clr.primary"/></xsl:when>
                        <xsl:when test="position() mod 5 = 2"><xsl:value-of select="$clr.primary2"/></xsl:when>
                        <xsl:when test="position() mod 5 = 3"><xsl:value-of select="$clr.accent"/></xsl:when>
                        <xsl:when test="position() mod 5 = 4"><xsl:value-of select="$clr.ok"/></xsl:when>
                        <xsl:otherwise><xsl:value-of select="$clr.primary3"/></xsl:otherwise>
                      </xsl:choose>
                    </xsl:variable>
                    <xsl:call-template name="bar">
                      <xsl:with-param name="label" select="$label"/>
                      <xsl:with-param name="val"   select="$avgHr"/>
                      <xsl:with-param name="max"   select="$max.cnd.hr"/>
                      <xsl:with-param name="n"     select="$n"/>
                      <xsl:with-param name="unit">h</xsl:with-param>
                      <xsl:with-param name="color" select="$color"/>
                    </xsl:call-template>
                  </xsl:for-each>
                </xsl:otherwise>
              </xsl:choose>
            </div>
          </div>

          <div class="two-col">
            <div class="panel">
              <h2>Event Type Mix</h2>
              <div class="hint">Share of CSP events by event type</div>
              <div class="donut-wrap">
                <div class="svg-col">
                  <xsl:call-template name="donut"/>
                </div>
                <div class="lg-col">
                  <xsl:call-template name="lg-row"><xsl:with-param name="color" select="$clr.ok"/><xsl:with-param name="label">Phase Completion</xsl:with-param><xsl:with-param name="n" select="$phaseComp"/><xsl:with-param name="pct" select="$pct.phase"/></xsl:call-template>
                  <xsl:call-template name="lg-row"><xsl:with-param name="color" select="$clr.primary"/><xsl:with-param name="label">State Completion</xsl:with-param><xsl:with-param name="n" select="$stateComp"/><xsl:with-param name="pct" select="$pct.state"/></xsl:call-template>
                  <xsl:call-template name="lg-row"><xsl:with-param name="color" select="$clr.accent"/><xsl:with-param name="label">Auto Action</xsl:with-param><xsl:with-param name="n" select="$auto"/><xsl:with-param name="pct" select="$pct.auto"/></xsl:call-template>
                  <xsl:call-template name="lg-row"><xsl:with-param name="color" select="$clr.bad"/><xsl:with-param name="label">Return (rework)</xsl:with-param><xsl:with-param name="n" select="$backward"/><xsl:with-param name="pct" select="$pct.back"/></xsl:call-template>
                </div>
              </div>
            </div>
            <div class="panel last">
              <h2>Backward Rate vs Target</h2>
              <div class="hint">Bullet &#183; red &gt;15% &#183; amber 5-15% &#183; green &lt;=5% &#183; target 5%</div>
              <xsl:call-template name="bullet"/>
            </div>
          </div>

          <div class="two-col">
            <div class="panel">
              <xsl:choose>
                <xsl:when test="count($req.phases.distinct) &gt; 0">
                  <h2>Requisition Phase Durations</h2>
                  <div class="hint">Avg minutes to complete each phase</div>
                </xsl:when>
                <xsl:when test="$hasReqDates &gt; 0">
                  <h2>Requisition Cycle Time</h2>
                  <div class="hint">Avg minutes between G_1 date milestones (Create, Approve, Open, First posted)</div>
                </xsl:when>
                <xsl:when test="count($allReqs.byPhase.distinct) &gt; 0">
                  <h2>Requisition Mix</h2>
                  <div class="hint">Count of requisitions per current phase (G_1/PHASE_NAME)</div>
                </xsl:when>
                <xsl:otherwise>
                  <h2>Requisition Phase Durations</h2>
                  <div class="hint">No requisition-side data available in the current extract.</div>
                </xsl:otherwise>
              </xsl:choose>
              <xsl:call-template name="colchart"/>
            </div>
            <div class="panel last">
              <h2>CSP Activity by Month</h2>
              <div class="hint">Heatmap of events grouped by year-month</div>
              <xsl:call-template name="heatmap"/>
            </div>
          </div>

          <div class="section">
            <h2>Event Type Breakdown</h2>
            <table class="etype">
              <thead>
                <tr>
                  <th>Event type</th>
                  <th class="num">Count</th>
                  <th>Share</th>
                </tr>
              </thead>
              <tbody>
                <xsl:call-template name="etype"><xsl:with-param name="lbl">Phase Completion</xsl:with-param><xsl:with-param name="n" select="$phaseComp"/><xsl:with-param name="c" select="$clr.ok"/></xsl:call-template>
                <xsl:call-template name="etype"><xsl:with-param name="lbl">State Completion</xsl:with-param><xsl:with-param name="n" select="$stateComp"/><xsl:with-param name="c" select="$clr.primary"/></xsl:call-template>
                <xsl:call-template name="etype"><xsl:with-param name="lbl">Auto Action</xsl:with-param><xsl:with-param name="n" select="$auto"/><xsl:with-param name="c" select="$clr.accent"/></xsl:call-template>
                <xsl:call-template name="etype"><xsl:with-param name="lbl">Return to Prior Phase (rework)</xsl:with-param><xsl:with-param name="n" select="$backward"/><xsl:with-param name="c" select="$clr.bad"/></xsl:call-template>
              </tbody>
            </table>
          </div>

          <div class="footer">HCM ANALYTICS &#183; CSP Process &#183; Oracle HCM Cloud</div>
        </div>
      </body>
    </html>
  </xsl:template>

  <xsl:template name="kpi">
    <xsl:param name="label"/>
    <xsl:param name="value"/>
    <xsl:param name="sub"/>
    <xsl:param name="color"/>
    <xsl:param name="last"/>
    <xsl:variable name="cls">
      <xsl:choose>
        <xsl:when test="$last=1">card last</xsl:when>
        <xsl:otherwise>card</xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <div class="{$cls}">
      <div class="accent" style="background:{$color};"></div>
      <div class="label"><xsl:value-of select="$label"/></div>
      <div class="value"><xsl:value-of select="$value"/></div>
      <div class="sub"><xsl:value-of select="$sub"/></div>
    </div>
  </xsl:template>

  <xsl:template name="bar">
    <xsl:param name="label"/>
    <xsl:param name="val"/>
    <xsl:param name="max"/>
    <xsl:param name="n"/>
    <xsl:param name="unit"/>
    <xsl:param name="color"/>
    <xsl:variable name="pct">
      <xsl:choose>
        <xsl:when test="$max=0">0</xsl:when>
        <xsl:otherwise><xsl:value-of select="($val * 100) div $max"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="pctS" select="format-number($pct,'0.0')"/>
    <div class="bar-row">
      <div class="lbl"><xsl:value-of select="$label"/><span class="n">n=<xsl:value-of select="$n"/></span></div>
      <div class="track"><div class="wrap"><div class="fill" style="width:{$pctS}%;background:{$color};"></div></div></div>
      <div class="val"><xsl:value-of select="format-number($val,'0.0')"/> <span><xsl:value-of select="$unit"/></span></div>
    </div>
  </xsl:template>

  <xsl:template name="etype">
    <xsl:param name="lbl"/>
    <xsl:param name="n"/>
    <xsl:param name="c"/>
    <xsl:variable name="pct">
      <xsl:choose>
        <xsl:when test="$total=0">0</xsl:when>
        <xsl:otherwise><xsl:value-of select="($n * 100) div $total"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="pctS" select="format-number($pct,'0.0')"/>
    <tr>
      <td><xsl:value-of select="$lbl"/></td>
      <td class="num"><b><xsl:value-of select="$n"/></b></td>
      <td><div class="wrap"><div class="fill" style="width:{$pctS}%;background:{$c};"></div></div></td>
    </tr>
  </xsl:template>

  <xsl:template name="lg-row">
    <xsl:param name="color"/>
    <xsl:param name="label"/>
    <xsl:param name="n"/>
    <xsl:param name="pct"/>
    <div class="legend-row">
      <div class="sw"><i style="background:{$color};"></i></div>
      <div class="lb"><xsl:value-of select="$label"/></div>
      <div class="vn"><xsl:value-of select="$n"/></div>
      <div class="vp"><xsl:value-of select="format-number($pct div 100,'0.0%')"/></div>
    </div>
  </xsl:template>

  <xsl:template name="donut">
    <xsl:variable name="p1S" select="format-number($pct.phase,'0.00')"/>
    <xsl:variable name="p2S" select="format-number($pct.state,'0.00')"/>
    <xsl:variable name="p3S" select="format-number($pct.auto,'0.00')"/>
    <xsl:variable name="p4S" select="format-number($pct.back,'0.00')"/>
    <xsl:variable name="off2" select="$pct.phase"/>
    <xsl:variable name="off3" select="$pct.phase + $pct.state"/>
    <xsl:variable name="off4" select="$pct.phase + $pct.state + $pct.auto"/>
    <xsl:variable name="off2S" select="format-number(-1 * $off2,'0.00')"/>
    <xsl:variable name="off3S" select="format-number(-1 * $off3,'0.00')"/>
    <xsl:variable name="off4S" select="format-number(-1 * $off4,'0.00')"/>
    <svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 200 200" preserveAspectRatio="xMidYMid meet">
      <circle cx="100" cy="100" r="70" fill="none" stroke="{$clr.bg}" stroke-width="26"/>
      <g transform="rotate(-90 100 100)">
        <circle cx="100" cy="100" r="70" fill="none" stroke="{$clr.ok}" stroke-width="26" pathLength="100" stroke-dasharray="{$p1S} 100" stroke-dashoffset="0"/>
        <circle cx="100" cy="100" r="70" fill="none" stroke="{$clr.primary}" stroke-width="26" pathLength="100" stroke-dasharray="{$p2S} 100" stroke-dashoffset="{$off2S}"/>
        <circle cx="100" cy="100" r="70" fill="none" stroke="{$clr.accent}" stroke-width="26" pathLength="100" stroke-dasharray="{$p3S} 100" stroke-dashoffset="{$off3S}"/>
        <circle cx="100" cy="100" r="70" fill="none" stroke="{$clr.bad}" stroke-width="26" pathLength="100" stroke-dasharray="{$p4S} 100" stroke-dashoffset="{$off4S}"/>
      </g>
      <text x="100" y="94" text-anchor="middle" font-size="28" font-weight="700" fill="{$clr.ink}" font-family="Helvetica,Arial,sans-serif"><xsl:value-of select="$total"/></text>
      <text x="100" y="116" text-anchor="middle" font-size="11" fill="{$clr.mute}" font-family="Helvetica,Arial,sans-serif">CSP events</text>
      <text x="100" y="132" text-anchor="middle" font-size="10" fill="{$clr.mute}" font-family="Helvetica,Arial,sans-serif">rework <xsl:value-of select="format-number($backward.rate,'0.0%')"/></text>
    </svg>
  </xsl:template>

  <xsl:template name="bullet">
    <xsl:variable name="actPct" select="$backward.rate * 100"/>
    <xsl:variable name="actW">
      <xsl:choose>
        <xsl:when test="$actPct &gt; 30">600</xsl:when>
        <xsl:otherwise><xsl:value-of select="format-number($actPct * 20,'0.0')"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 640 100" preserveAspectRatio="none">
      <rect x="0"   y="30" width="100" height="36" fill="#D1FAE5"/>
      <rect x="100" y="30" width="200" height="36" fill="#FEF3C7"/>
      <rect x="300" y="30" width="300" height="36" fill="#FEE2E2"/>
      <rect x="0"   y="40" width="{$actW}" height="16" fill="{$clr.ink}"/>
      <line x1="100" y1="22" x2="100" y2="74" stroke="{$clr.primary}" stroke-width="4"/>
      <text x="100" y="18" font-size="11" fill="{$clr.primary}" font-weight="700" text-anchor="middle" font-family="Helvetica,Arial,sans-serif">Target 5%</text>
      <text x="0"   y="88" font-size="10" fill="{$clr.mute}" font-family="Helvetica,Arial,sans-serif">0%</text>
      <text x="100" y="88" font-size="10" fill="{$clr.mute}" font-family="Helvetica,Arial,sans-serif" text-anchor="middle">5%</text>
      <text x="300" y="88" font-size="10" fill="{$clr.mute}" font-family="Helvetica,Arial,sans-serif" text-anchor="middle">15%</text>
      <text x="600" y="88" font-size="10" fill="{$clr.mute}" font-family="Helvetica,Arial,sans-serif" text-anchor="end">30%+</text>
      <text x="320" y="20" font-size="15" font-weight="700" fill="{$clr.ink}" text-anchor="middle" font-family="Helvetica,Arial,sans-serif">Backward Rate: <xsl:value-of select="format-number($backward.rate,'0.0%')"/></text>
    </svg>
  </xsl:template>

  <xsl:template name="colchart">
    <svg xmlns="http://www.w3.org/2000/svg" width="100%" viewBox="0 0 560 240" preserveAspectRatio="xMidYMid meet">
      <xsl:choose>
        <xsl:when test="count($req.phases.distinct) = 0 and $hasReqDates = 0 and count($allReqs.byPhase.distinct) = 0">
          <text x="280" y="120" text-anchor="middle" font-size="13" fill="{$clr.mute}" font-family="Helvetica,Arial,sans-serif">No requisition-side data available.</text>
        </xsl:when>
        <xsl:when test="count($req.phases.distinct) = 0 and $hasReqDates &gt; 0">
          <!-- Cycle-time columns from G_1 ISO milestones — same 4 transitions, mirrored from the bar panel. -->
          <xsl:variable name="cw" select="520 div 4"/>
          <xsl:variable name="barW" select="$cw - 12"/>
          <xsl:call-template name="col">
            <xsl:with-param name="x"     select="20 + ($cw * 0)"/>
            <xsl:with-param name="w"     select="$barW"/>
            <xsl:with-param name="n"     select="number($avg.creToApp.min)"/>
            <xsl:with-param name="label">Create&#8594;Approve</xsl:with-param>
            <xsl:with-param name="color" select="$clr.primary"/>
            <xsl:with-param name="scale" select="number($max.req.dates.min)"/>
          </xsl:call-template>
          <xsl:call-template name="col">
            <xsl:with-param name="x"     select="20 + ($cw * 1)"/>
            <xsl:with-param name="w"     select="$barW"/>
            <xsl:with-param name="n"     select="number($avg.appToOpn.min)"/>
            <xsl:with-param name="label">Approve&#8594;Open</xsl:with-param>
            <xsl:with-param name="color" select="$clr.primary2"/>
            <xsl:with-param name="scale" select="number($max.req.dates.min)"/>
          </xsl:call-template>
          <xsl:call-template name="col">
            <xsl:with-param name="x"     select="20 + ($cw * 2)"/>
            <xsl:with-param name="w"     select="$barW"/>
            <xsl:with-param name="n"     select="number($avg.opnToInt.min)"/>
            <xsl:with-param name="label">Open&#8594;Post(Int)</xsl:with-param>
            <xsl:with-param name="color" select="$clr.accent"/>
            <xsl:with-param name="scale" select="number($max.req.dates.min)"/>
          </xsl:call-template>
          <xsl:call-template name="col">
            <xsl:with-param name="x"     select="20 + ($cw * 3)"/>
            <xsl:with-param name="w"     select="$barW"/>
            <xsl:with-param name="n"     select="number($avg.opnToExt.min)"/>
            <xsl:with-param name="label">Open&#8594;Post(Ext)</xsl:with-param>
            <xsl:with-param name="color" select="$clr.ok"/>
            <xsl:with-param name="scale" select="number($max.req.dates.min)"/>
          </xsl:call-template>
          <line x1="0" y1="200" x2="560" y2="200" stroke="{$clr.line}" stroke-width="1"/>
        </xsl:when>
        <xsl:when test="count($req.phases.distinct) = 0">
          <!-- Fallback: requisition count per current phase from G_1 -->
          <xsl:for-each select="$allReqs.byPhase.distinct">
            <xsl:sort select="count(key('reqGroupByPhase', PHASE_CODE))" data-type="number" order="descending"/>
            <xsl:variable name="n" select="count(key('reqGroupByPhase', PHASE_CODE))"/>
            <xsl:variable name="cw" select="520 div last()"/>
            <xsl:variable name="cx" select="20 + ($cw * (position() - 1))"/>
            <xsl:variable name="barW" select="$cw - 12"/>
            <xsl:variable name="label">
              <xsl:choose>
                <xsl:when test="string-length(PHASE_NAME) &gt; 0"><xsl:value-of select="PHASE_NAME"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="PHASE_CODE"/></xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:variable name="color">
              <xsl:choose>
                <xsl:when test="position() mod 5 = 1"><xsl:value-of select="$clr.primary"/></xsl:when>
                <xsl:when test="position() mod 5 = 2"><xsl:value-of select="$clr.primary2"/></xsl:when>
                <xsl:when test="position() mod 5 = 3"><xsl:value-of select="$clr.accent"/></xsl:when>
                <xsl:when test="position() mod 5 = 4"><xsl:value-of select="$clr.ok"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="$clr.primary3"/></xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:call-template name="col">
              <xsl:with-param name="x"     select="$cx"/>
              <xsl:with-param name="w"     select="$barW"/>
              <xsl:with-param name="n"     select="$n"/>
              <xsl:with-param name="label" select="$label"/>
              <xsl:with-param name="color" select="$color"/>
              <xsl:with-param name="scale" select="$max.reqMix"/>
            </xsl:call-template>
          </xsl:for-each>
          <line x1="0" y1="200" x2="560" y2="200" stroke="{$clr.line}" stroke-width="1"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="$req.phases.distinct">
            <xsl:sort select="sum(key('reqPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('reqPhaseComp', PHASE_CODE)) div 60" data-type="number" order="descending"/>
            <xsl:variable name="grp" select="key('reqPhaseComp', PHASE_CODE)"/>
            <xsl:variable name="avgMin" select="sum($grp/STEP_DURATION) div count($grp) div 60"/>
            <xsl:variable name="cw" select="520 div last()"/>
            <xsl:variable name="cx" select="20 + ($cw * (position() - 1))"/>
            <xsl:variable name="barW" select="$cw - 12"/>
            <xsl:variable name="label">
              <xsl:choose>
                <xsl:when test="string-length(PHASE_NAME) &gt; 0"><xsl:value-of select="PHASE_NAME"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="PHASE_CODE"/></xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:variable name="color">
              <xsl:choose>
                <xsl:when test="position() mod 5 = 1"><xsl:value-of select="$clr.primary"/></xsl:when>
                <xsl:when test="position() mod 5 = 2"><xsl:value-of select="$clr.primary2"/></xsl:when>
                <xsl:when test="position() mod 5 = 3"><xsl:value-of select="$clr.accent"/></xsl:when>
                <xsl:when test="position() mod 5 = 4"><xsl:value-of select="$clr.ok"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="$clr.primary3"/></xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:call-template name="col">
              <xsl:with-param name="x"     select="$cx"/>
              <xsl:with-param name="w"     select="$barW"/>
              <xsl:with-param name="n"     select="$avgMin"/>
              <xsl:with-param name="label" select="$label"/>
              <xsl:with-param name="color" select="$color"/>
            </xsl:call-template>
          </xsl:for-each>
          <line x1="0" y1="200" x2="560" y2="200" stroke="{$clr.line}" stroke-width="1"/>
        </xsl:otherwise>
      </xsl:choose>
    </svg>
  </xsl:template>

  <xsl:template name="col">
    <xsl:param name="x"/>
    <xsl:param name="w" select="90"/>
    <xsl:param name="n"/>
    <xsl:param name="label"/>
    <xsl:param name="color"/>
    <xsl:param name="scale" select="$max.req.min"/>
    <xsl:variable name="h">
      <xsl:choose>
        <xsl:when test="$scale=0">0</xsl:when>
        <xsl:otherwise><xsl:value-of select="($n * 170) div $scale"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:variable name="hS" select="format-number($h,'0.0')"/>
    <xsl:variable name="yS" select="format-number(200 - $h,'0.0')"/>
    <xsl:variable name="lS" select="format-number(200 - $h - 6,'0.0')"/>
    <xsl:variable name="cx" select="$x + ($w div 2)"/>
    <rect x="{$x}" y="{$yS}" width="{$w}" height="{$hS}" rx="3" ry="3" fill="{$color}"/>
    <text x="{$cx}" y="{$lS}" text-anchor="middle" font-size="12" font-weight="700" fill="{$clr.ink}" font-family="Helvetica,Arial,sans-serif"><xsl:value-of select="format-number($n,'0.0')"/></text>
    <text x="{$cx}" y="218" text-anchor="middle" font-size="10" fill="{$clr.mute}" font-family="Helvetica,Arial,sans-serif"><xsl:value-of select="$label"/></text>
  </xsl:template>

  <xsl:template name="heatmap">
    <xsl:variable name="mcount" select="count($months)"/>
    <xsl:variable name="mmax">
      <xsl:for-each select="$months">
        <xsl:sort select="count(key('cspMonth', substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE),1,7)))" data-type="number" order="descending"/>
        <xsl:if test="position()=1"><xsl:value-of select="count(key('cspMonth', substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE),1,7)))"/></xsl:if>
      </xsl:for-each>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="$mcount = 0">
        <div class="heat-legend">No event dates available in dataset.</div>
      </xsl:when>
      <xsl:otherwise>
        <div class="heat-grid">
          <xsl:for-each select="$months">
            <xsl:sort select="substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE),1,7)" order="ascending"/>
            <xsl:variable name="ym" select="substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE),1,7)"/>
            <xsl:variable name="n" select="count(key('cspMonth', $ym))"/>
            <xsl:variable name="intensity">
              <xsl:choose>
                <xsl:when test="$mmax=0">0</xsl:when>
                <xsl:otherwise><xsl:value-of select="$n div $mmax"/></xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:variable name="bg">
              <xsl:choose>
                <xsl:when test="$intensity &gt;= 0.80">#3200EB</xsl:when>
                <xsl:when test="$intensity &gt;= 0.60">#5F3BFF</xsl:when>
                <xsl:when test="$intensity &gt;= 0.40">#8B5CF6</xsl:when>
                <xsl:when test="$intensity &gt;= 0.20">#B8A7FF</xsl:when>
                <xsl:otherwise>#DDD5FF</xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <xsl:variable name="tc">
              <xsl:choose>
                <xsl:when test="$intensity &gt;= 0.40">#FFFFFF</xsl:when>
                <xsl:otherwise>#0F172A</xsl:otherwise>
              </xsl:choose>
            </xsl:variable>
            <div class="heat-cell" style="background:{$bg};color:{$tc};">
              <div class="m"><xsl:value-of select="$ym"/></div>
              <div class="v"><xsl:value-of select="$n"/></div>
            </div>
          </xsl:for-each>
        </div>
        <div class="heat-legend">Peak: <b style="color:#0F172A;"><xsl:value-of select="$mmax"/></b> events in the busiest month &#183; <xsl:value-of select="$mcount"/> distinct months</div>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- ISO-8601 timestamp diff in minutes (approximation).
       Input format: YYYY-MM-DDTHH:MM:SS.fff+HH:MM
       Approximation: year*525600 + month*43830 + day*1440 + hour*60 + min + sec/60
       — month term cancels when same month; day term is exact. -->
  <xsl:template name="iso-diff-min">
    <xsl:param name="a"/>
    <xsl:param name="b"/>
    <xsl:variable name="ya" select="number(substring($a,1,4))"/>
    <xsl:variable name="ma" select="number(substring($a,6,2))"/>
    <xsl:variable name="da" select="number(substring($a,9,2))"/>
    <xsl:variable name="ha" select="number(substring($a,12,2))"/>
    <xsl:variable name="na" select="number(substring($a,15,2))"/>
    <xsl:variable name="sa" select="number(substring($a,18,2))"/>
    <xsl:variable name="yb" select="number(substring($b,1,4))"/>
    <xsl:variable name="mb" select="number(substring($b,6,2))"/>
    <xsl:variable name="db" select="number(substring($b,9,2))"/>
    <xsl:variable name="hb" select="number(substring($b,12,2))"/>
    <xsl:variable name="nb" select="number(substring($b,15,2))"/>
    <xsl:variable name="sb" select="number(substring($b,18,2))"/>
    <xsl:variable name="ta" select="$ya*525600 + $ma*43830 + $da*1440 + $ha*60 + $na + ($sa div 60)"/>
    <xsl:variable name="tb" select="$yb*525600 + $mb*43830 + $db*1440 + $hb*60 + $nb + ($sb div 60)"/>
    <xsl:value-of select="$tb - $ta"/>
  </xsl:template>

  <!-- Recursive accumulator for minute-diffs across a node-set.
       $mode picks which pair of columns to diff on each node.
       Total returned as a numeric string; divide by count($nodes) for avg. -->
  <xsl:template name="sum-diff-min">
    <xsl:param name="nodes"/>
    <xsl:param name="mode"/>
    <xsl:param name="acc" select="0"/>
    <xsl:choose>
      <xsl:when test="count($nodes) = 0"><xsl:value-of select="$acc"/></xsl:when>
      <xsl:otherwise>
        <xsl:variable name="node" select="$nodes[1]"/>
        <xsl:variable name="a">
          <xsl:choose>
            <xsl:when test="$mode='creToApp'"><xsl:value-of select="$node/CREATION_DATE"/></xsl:when>
            <xsl:when test="$mode='appToOpn'"><xsl:value-of select="$node/APPROVED_DATE"/></xsl:when>
            <xsl:when test="$mode='opnToInt'"><xsl:value-of select="$node/OPEN_DATE"/></xsl:when>
            <xsl:when test="$mode='opnToExt'"><xsl:value-of select="$node/OPEN_DATE"/></xsl:when>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="b">
          <xsl:choose>
            <xsl:when test="$mode='creToApp'"><xsl:value-of select="$node/APPROVED_DATE"/></xsl:when>
            <xsl:when test="$mode='appToOpn'"><xsl:value-of select="$node/OPEN_DATE"/></xsl:when>
            <xsl:when test="$mode='opnToInt'"><xsl:value-of select="$node/INT_FIRST_POSTED_DATE"/></xsl:when>
            <xsl:when test="$mode='opnToExt'"><xsl:value-of select="$node/EXT_FIRST_POSTED_DATE"/></xsl:when>
          </xsl:choose>
        </xsl:variable>
        <xsl:variable name="d">
          <xsl:call-template name="iso-diff-min">
            <xsl:with-param name="a" select="string($a)"/>
            <xsl:with-param name="b" select="string($b)"/>
          </xsl:call-template>
        </xsl:variable>
        <xsl:call-template name="sum-diff-min">
          <xsl:with-param name="nodes" select="$nodes[position() &gt; 1]"/>
          <xsl:with-param name="mode"  select="$mode"/>
          <xsl:with-param name="acc"   select="$acc + number($d)"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
