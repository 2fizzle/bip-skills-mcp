# Adaptive Fallback (N-Way xsl:choose)

## When to use

Your primary data source might be structurally missing from some extracts. Rather than showing an empty panel, fall back to progressively weaker signals from the same extract.

Example from the CSP Process Analytics dashboard: the "Requisition Lifecycle" panel ideally shows average step-duration per phase, sourced from `G_14[SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION']`. But in the requisitions data model those events live under `G_2` (submission-level), so they all carry `SOURCE_OBJECT_ID='4'` — there are zero req-side events by construction.

Instead of an empty panel, the XSL falls back to cycle time computed from `G_1` date milestones (Create → Approve → Open → Post). And if those dates are absent too, it falls back to a simple count of reqs per current phase. And if the extract has no reqs at all, it shows an honest empty state.

## The pattern

Declare one boolean/count variable per branch's precondition. Then an `xsl:choose` picks the first branch whose precondition is met:

```xml
<!-- Precondition variables -->
<xsl:variable name="req.phases"          select="$csp[SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) > 0]"/>
<xsl:variable name="req.phases.distinct" select="$req.phases[count(. | key('reqPhaseComp', PHASE_CODE)[1]) = 1]"/>

<xsl:variable name="reqs.creToApp" select="/DATA_DS/G_1[REQUISITION_ID and string-length(CREATION_DATE) >= 19 and string-length(APPROVED_DATE) >= 19]"/>
<xsl:variable name="reqs.appToOpn" select="/DATA_DS/G_1[REQUISITION_ID and string-length(APPROVED_DATE) >= 19 and string-length(OPEN_DATE) >= 19]"/>
<xsl:variable name="hasReqDates"   select="count($reqs.creToApp) + count($reqs.appToOpn)"/>

<xsl:variable name="allReqs"                  select="/DATA_DS/G_1[REQUISITION_ID and string-length(PHASE_CODE) > 0]"/>
<xsl:variable name="allReqs.byPhase.distinct" select="$allReqs[count(. | key('reqGroupByPhase', PHASE_CODE)[1]) = 1]"/>

<!-- Render with adaptive fallback -->
<xsl:choose>
  <xsl:when test="count($req.phases.distinct) > 0">
    <!-- Branch 1: real step-duration data -->
    <xsl:for-each select="$req.phases.distinct">
      ...
    </xsl:for-each>
  </xsl:when>
  <xsl:when test="$hasReqDates > 0">
    <!-- Branch 2: cycle time from G_1 ISO date milestones -->
    ...
  </xsl:when>
  <xsl:when test="count($allReqs.byPhase.distinct) > 0">
    <!-- Branch 3: count of reqs per current phase -->
    ...
  </xsl:when>
  <xsl:otherwise>
    <!-- Branch 4: honest empty state -->
  </xsl:otherwise>
</xsl:choose>
```

## Mirror the choice for the heading

The panel title has to match what's actually being shown. Use the same `xsl:choose` for the heading:

```xml
<xsl:choose>
  <xsl:when test="count($req.phases.distinct) > 0">
    <h2>Requisition Lifecycle · avg minutes</h2>
    <div class="hint">SOURCE_OBJECT_ID = 1 · PHASE_COMPLETION events · phases discovered dynamically</div>
  </xsl:when>
  <xsl:when test="$hasReqDates > 0">
    <h2>Requisition Lifecycle · avg minutes (cycle time)</h2>
    <div class="hint">Derived from G_1 date milestones: Creation → Approved → Open → First posted</div>
  </xsl:when>
  <xsl:when test="count($allReqs.byPhase.distinct) > 0">
    <h2>Requisition Mix · current phase</h2>
    <div class="hint">No req-side PHASE_COMPLETION events — showing requisition count per phase</div>
  </xsl:when>
  <xsl:otherwise>
    <h2>Requisition Lifecycle</h2>
    <div class="hint">No requisition-side data available in the current extract.</div>
  </xsl:otherwise>
</xsl:choose>
```

## Ordering the branches

From strongest signal to weakest. "Stronger" means the value is closer to what the panel's title promises. Step durations from actual phase-completion events are the ground truth; date-diffs are derived; phase counts don't describe durations at all.

Only expose a branch whose units and labels are honest about what the user is seeing. If branch 3 in the example above were labeled "avg minutes" it would be misleading. Renaming to "Requisition Mix" is the honest choice.

## Avoiding unit drift

When adjacent branches have different units (minutes vs hours vs count), the `bar` template needs to accept the unit as a parameter:

```xml
<xsl:call-template name="bar">
  <xsl:with-param name="val"   select="$avgMin"/>
  <xsl:with-param name="unit">min</xsl:with-param>
  ...
</xsl:call-template>
```

Never hardcode "min" inside the bar template itself. The unit belongs to the caller.

## Dynamic scale per branch

Each branch will have its own max value. Declare one scale variable per branch:

```xml
<xsl:variable name="max.req.min">
  <xsl:choose>
    <xsl:when test="count($req.phases.distinct) = 0">0</xsl:when>
    <xsl:otherwise>
      <xsl:for-each select="$req.phases.distinct">
        <xsl:sort select="sum(key('reqPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('reqPhaseComp', PHASE_CODE)) div 60"
                  data-type="number" order="descending"/>
        <xsl:if test="position()=1">
          <xsl:value-of select="sum(key('reqPhaseComp', PHASE_CODE)/STEP_DURATION) div count(key('reqPhaseComp', PHASE_CODE)) div 60"/>
        </xsl:if>
      </xsl:for-each>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>

<xsl:variable name="max.req.dates.min">
  <!-- max of the 4 avg-min values -->
  <xsl:choose>
    <xsl:when test="number($avg.creToApp.min) >= number($avg.appToOpn.min)
                and number($avg.creToApp.min) >= number($avg.opnToInt.min)
                and number($avg.creToApp.min) >= number($avg.opnToExt.min)">
      <xsl:value-of select="$avg.creToApp.min"/>
    </xsl:when>
    ...
  </xsl:choose>
</xsl:variable>
```

Pass the right scale to the bar template per branch.

## Validation

Every branch must be reachable by at least one of your test XML inputs. If a branch is never hit, you can't know if it works. Either add an input that hits it or remove the branch.

Regex the rendered heading from each preview to confirm you got the expected branch:

```python
import re
m = re.search(r'<h2>([^<]+)</h2>', html)
print(f'{name}: rendered heading = {m.group(1)}')
```
