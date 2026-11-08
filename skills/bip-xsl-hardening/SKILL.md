---
name: bip-xsl-hardening
description: "Make Oracle BI Publisher HTML XSL dashboards locale-independent, robust across data-model shapes, and gracefully degrading when expected data is missing. Use whenever you're patching, building, or debugging an Oracle BIP HTML.xsl dashboard (xdo11g / XSLT 1.0) — including symptoms like 'all bars show zero', 'labels are wrong in French/Spanish/etc.', 'chart is empty after data model change', 'need duration in minutes between two date columns', 'EXSLT date functions don't work in BIP', 'events nested differently in production vs test extract', or building any IRC/HCM/BIP dashboard that needs to survive across locales and tenant data shapes. Also trigger for Muenchian grouping, dynamic phase discovery, locale-independent grouping, multi-shape XML support, recursive XSLT 1.0 templates, ISO-8601 date arithmetic without EXSLT, adaptive panel headings, and N-way fallback chains in XSL."
---

# BI Publisher XSL Hardening

A toolbox of XSLT 1.0 patterns for building Oracle BI Publisher HTML dashboards that survive real-world conditions: locale changes, data-model evolution, missing data in some tenants, no EXSLT support, and report bursts where one extract differs structurally from another.

## Why this skill exists

Oracle BI Publisher (xdo11g and earlier) ships with an XSLT 1.0 engine. No EXSLT date functions, no `xsl:function`, no dynamic xpath evaluation. Combine that with the realities of HCM/IRC reporting — French / Spanish / Portuguese / Mandarin tenants, evolving data models where the same fact appears at different XML levels in different report bursts, and stakeholders who expect a chart to keep working when the underlying data shifts — and you have a fragile combination.

The patterns in this skill are the ones that, in practice, keep BIP HTML dashboards running across all those conditions. Each pattern is small. The power comes from layering them.

## When to apply each pattern

Read the symptoms first, then the cure.

| Symptom | Pattern | Reference |
|---|---|---|
| Bars all show zero in production but worked in dev | Hardcoded English label filter (`PHASE_NAME='Job formatting'`) doesn't match French label | `references/locale-independent-grouping.md` |
| Different bursts of the same report fail because data is at different XML depths | Single union xpath that accepts both shapes (`G_14 \| G_1[HISTORY_EVENT_ID]`) | `references/multi-shape-support.md` |
| Empty-state shown when extract structurally cannot carry the expected data | N-way `xsl:choose` with progressively weaker fallbacks | `references/adaptive-fallback.md` |
| Need average minutes between two ISO-8601 date columns | Recursive named templates: `iso-diff-min` + `sum-diff-min` | `references/xslt1-date-arithmetic.md` |
| Date column has different name across extract types (`EVENT_OCCURRED_DATE` vs `TRANSITION_DATE`) | `substring(concat(A, B), 1, 7)` coalesce | `references/multi-shape-support.md` |
| Panel heading needs to reflect which fallback branch actually rendered | Mirror the `xsl:choose` for the heading | `references/adaptive-fallback.md` |
| Chart axis hardcoded but data is now bigger or smaller | Dynamic max via `xsl:sort` + `position()=1` | `references/adaptive-fallback.md` |

## The five core patterns at a glance

### 1. Group on codes, label from names

Locale-independent dashboards group on `*_CODE` fields (immutable identifiers like `'JOB_POSTING'`) and pull display strings from `*_NAME` fields on the same row. The code drives the bucket; the name decorates it. Same XSL produces "Job posting" / "Mise en forme de l'emploi" / "Publicación de empleo" without any conditional logic.

```xml
<xsl:key name="byPhase" match="G_14[EVENT_TYPE_CODE='PHASE_COMPLETION']" use="PHASE_CODE"/>
<xsl:variable name="phases" select="$rows[count(. | key('byPhase', PHASE_CODE)[1]) = 1]"/>

<xsl:for-each select="$phases">
  <xsl:variable name="grp" select="key('byPhase', PHASE_CODE)"/>
  <xsl:value-of select="PHASE_NAME"/>  <!-- locale-correct label -->
  <xsl:value-of select="sum($grp/STEP_DURATION) div count($grp)"/>
</xsl:for-each>
```

This is Muenchian grouping (XSLT 1.0's stand-in for `xsl:for-each-group`). The trick: `count(. | key(...)[1]) = 1` is true exactly for the first node in each group.

### 2. Accept multiple data shapes with a union xpath

Real BIP report bursts are not consistent. The same logical fact (a CSP history event) might be nested under `G_1/G_2/G_14` in the requisitions extract but appear at root as `G_1[HISTORY_EVENT_ID]` in a standalone CSP history extract. Don't write two stylesheets — use a union xpath:

```xml
<xsl:variable name="csp" select="/DATA_DS/G_1/G_2/G_14 | /DATA_DS/G_1[HISTORY_EVENT_ID]"/>
```

Apply the same pattern to keys:

```xml
<xsl:key name="byPhase"
         match="G_14[SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION']
              | G_1[HISTORY_EVENT_ID and SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION']"
         use="PHASE_CODE"/>
```

When field names also differ between shapes (e.g. `EVENT_OCCURRED_DATE` vs `TRANSITION_DATE`), coalesce with `concat`:

```xml
<xsl:variable name="ym" select="substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE), 1, 7)"/>
```

`concat` of the populated and missing field is just the populated one. Works because exactly one is non-empty.

### 3. N-way adaptive fallback for missing data

When the primary data source is structurally absent in some extracts, render something useful instead of an empty state. Order from "best signal" to "weakest signal" to "empty":

```xml
<xsl:choose>
  <xsl:when test="count($req.phases.distinct) > 0">
    <!-- Branch 1: real step-duration data -->
  </xsl:when>
  <xsl:when test="$hasReqDates > 0">
    <!-- Branch 2: cycle time from G_1 ISO date milestones -->
  </xsl:when>
  <xsl:when test="count($allReqs.byPhase.distinct) > 0">
    <!-- Branch 3: count of reqs per current phase -->
  </xsl:when>
  <xsl:otherwise>
    <!-- Branch 4: empty state with helpful message -->
  </xsl:otherwise>
</xsl:choose>
```

Mirror the same `xsl:choose` for the panel heading so the title accurately describes what's being shown:

```xml
<xsl:choose>
  <xsl:when test="count($req.phases.distinct) > 0">
    <h2>Requisition Lifecycle · avg minutes</h2>
  </xsl:when>
  <xsl:when test="$hasReqDates > 0">
    <h2>Requisition Lifecycle · avg minutes (cycle time)</h2>
  </xsl:when>
  ...
</xsl:choose>
```

### 4. Date arithmetic in pure XSLT 1.0

xdo11g doesn't have EXSLT. To compute minutes between two ISO-8601 timestamps, parse with `substring`/`number` and use the approximation `year*525600 + month*43830 + day*1440 + hour*60 + min + sec/60`. Aggregate across a node-set with a tail-recursive named template.

Full implementation in `references/xslt1-date-arithmetic.md`.

### 5. Dynamic chart scaling

Hardcoded axis maxes break when data scales up or down. Compute the max with `xsl:sort` + `position()=1`:

```xml
<xsl:variable name="max.val">
  <xsl:choose>
    <xsl:when test="count($groups) = 0">0</xsl:when>
    <xsl:otherwise>
      <xsl:for-each select="$groups">
        <xsl:sort select="sum(key('k', CODE)/VAL) div count(key('k', CODE))"
                  data-type="number" order="descending"/>
        <xsl:if test="position()=1">
          <xsl:value-of select="sum(key('k', CODE)/VAL) div count(key('k', CODE))"/>
        </xsl:if>
      </xsl:for-each>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>
```

For column-chart widths that should distribute evenly regardless of phase count, use `last()`:

```xml
<xsl:variable name="cw" select="520 div last()"/>
```

## How to work through a patching session

The fastest path is to read the XSL, identify which symptoms apply, and apply one pattern at a time, rendering against representative XML inputs after each change.

**Step 1 — gather inputs.** Find at least two real XML payloads representing different shapes / locales / data densities. Without this you can't validate that your changes work everywhere.

**Step 2 — diagnose the failure mode.** Match the symptom to a pattern in the table above. Don't apply patterns speculatively.

**Step 3 — apply the pattern locally.** Edit the XSL. Keep the change small. The point is to be able to render and check each pattern in isolation.

**Step 4 — render against every input.** Use lxml or saxon-he. Confirm the patched branch produces sensible output AND that other branches still work for inputs that should hit them.

```python
from lxml import etree
parser = etree.XMLParser(recover=True)  # tolerate truncated uploads
xsl = etree.XSLT(etree.parse('dashboard.xsl'))
for path in inputs:
    out = xsl(etree.parse(path, parser))
    open(f'preview_{path.stem}.html', 'wb').write(bytes(out))
```

**Step 5 — extract values from the rendered HTML to confirm correctness.** Don't just eyeball — regex the bar values out and check them against expectations. If `Create→Approve` should be ~9 minutes given the source timestamps, the regex output should show `8.9 min` not `0.0 min`.

## Worked example

`assets/02_CSP_Process_Analytics.HTML.xsl` is a complete dashboard XSL applying every pattern in this skill. Read it when you need to see the patterns layered together — particularly:

- Lines 6–24: keys with union xpath matchers
- Lines 39–45: union xpath data variable + counts
- Lines 60–69: dynamic phase discovery (Muenchian on PHASE_CODE)
- Lines 71–78: date-diff cohort variables
- Lines 80–146: aggregate sum/avg/max variables
- Lines 247–322: 4-way adaptive Requisition Lifecycle panel with mirrored heading
- Lines 717–781: `iso-diff-min` and `sum-diff-min` recursive templates

## Things to avoid

Hardcoded `*_NAME` values in xpath predicates. They will fail the moment the report runs in a different locale.

Multiple competing stylesheets for different extract shapes. Maintainability collapses. Use union xpaths.

`xsl:if test="$count = 0"` empty-state branches without a useful fallback. If the data exists in some other form, show it — even with a different unit and an honest heading.

EXSLT date functions (`date:diff`, `date:add`, `date:seconds`). They aren't available in xdo11g and will throw at runtime even though they parse fine.

Hardcoded chart axis maxes. They break when data scales.

Generating intermediate result-tree-fragments and comparing them with `&gt;` without wrapping in `number()`. XSLT 1.0 will silently string-compare and you'll get wrong answers.

## Validation checklist before delivering

- [ ] XSL parses with `lxml.etree.XSLT()` (catches syntax errors).
- [ ] Renders cleanly against every representative XML input you have.
- [ ] Each adaptive branch reachable by at least one input.
- [ ] Bar/column values regex-extracted from output match hand-calculated expectations.
- [ ] Panel headings match what's actually shown in the body.
- [ ] No hardcoded English labels left in xpath predicates (grep for `_NAME='`).
- [ ] No EXSLT functions in use (grep for `date:`, `regexp:`).
- [ ] Result-tree-fragment comparisons wrapped in `number()`.
