# Date Arithmetic in XSLT 1.0 (No EXSLT)

## Why you need this

Oracle BI Publisher (xdo11g and earlier) ships with an XSLT 1.0 engine that does not include EXSLT date functions. Calling `date:diff` or `date:seconds` parses fine in lxml locally, but at BIP runtime you get:

```
oracle.xdo.parser.v2.XPathException: Undefined function: date:diff
```

You need to compute durations using only core XPath 1.0: `substring`, `number`, arithmetic operators, and recursive named templates.

## The approximation

Convert each ISO-8601 timestamp to "minutes-since-epoch" and subtract.

```
minutes = year*525600 + month*43830 + day*1440 + hour*60 + minute + sec/60
```

This is not astronomically accurate (months don't all have 30.4375 days, leap years aren't modeled), but it's exact for:

- Same-day diffs — the year/month/day terms cancel completely, leaving hour×60 + minute + sec/60.
- Same-month diffs — year/month cancel; day term is exact (1440 min/day).
- Cross-month diffs within the same year — day term is exact; month term is approximate (30.4375 days/month average).
- Cross-year diffs — both month and year terms are approximate.

For cycle-time analytics (Create→Approve, Open→Post, etc.), where most diffs are same-day to a few weeks, the error is under 1% and vanishes for shorter intervals.

If you need exact year-boundary calculations, sum days-per-month explicitly — but it's rarely worth the complexity.

## The two templates

### `iso-diff-min` — scalar diff between two ISO timestamps

```xml
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
```

The `substring` positions are hardcoded to ISO-8601 format `YYYY-MM-DDTHH:MM:SS[.fff][timezone]`:

| Position | Field |
|----------|-------|
| 1–4      | year |
| 6–7      | month |
| 9–10     | day |
| 12–13    | hour |
| 15–16    | minute |
| 18–19    | seconds |

If the string is shorter than 19 characters, `number(substring(...))` returns `NaN` and the arithmetic propagates it. Filter cohorts with `string-length(DATE_FIELD) >= 19` before feeding them to this template.

### `sum-diff-min` — recursive aggregator

There's no `xsl:function` in 1.0 and no way to map across a node-set without recursion. Tail-recurse through `$nodes[position() > 1]`, accumulating into `$acc`:

```xml
<xsl:template name="sum-diff-min">
  <xsl:param name="nodes"/>
  <xsl:param name="mode"/>
  <xsl:param name="acc" select="0"/>
  <xsl:choose>
    <xsl:when test="count($nodes) = 0">
      <xsl:value-of select="$acc"/>
    </xsl:when>
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
```

## Why `mode` and not two xpath params

XSLT 1.0 has no dynamic xpath evaluation. You can't pass `"CREATION_DATE"` as a string and then `select="$node/*[name()=$col]"` — well, you *can*, but it's painful and the syntax doesn't compose through multiple levels.

A `mode` parameter with an enumerated switch is verbose but honest. Add a new case per transition you need to measure. The alternative is one template per transition, which bloats faster than adding `when` clauses.

## Using it from global variables

XSLT 1.0 allows a global variable to invoke a named template. This is how you pre-compute aggregates once, without putting template calls in the render body:

```xml
<xsl:variable name="sum.creToApp.min">
  <xsl:call-template name="sum-diff-min">
    <xsl:with-param name="nodes" select="$reqs.creToApp"/>
    <xsl:with-param name="mode"  select="'creToApp'"/>
  </xsl:call-template>
</xsl:variable>

<xsl:variable name="avg.creToApp.min">
  <xsl:choose>
    <xsl:when test="count($reqs.creToApp) = 0">0</xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="number($sum.creToApp.min) div count($reqs.creToApp)"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>
```

The template can be defined anywhere in the stylesheet — after the variable is fine, templates have global scope.

## Result-tree-fragment traps

`$sum.creToApp.min` is not a number, it's a result tree fragment (RTF). Two gotchas:

1. **Division auto-converts.** `$sum div count(...)` works because `div` promotes both sides to `number()`.
2. **Comparison does NOT always auto-convert.** `$a &gt; $b` where both are RTFs may compare as strings (`"10"` &lt; `"9"` lexically!). Wrap explicitly: `number($a) &gt; number($b)`.

Always wrap RTFs in `number()` when comparing. This is the #1 source of subtle bugs in XSLT 1.0 date math.

## Hour conversion

If the expected magnitude is in hours rather than minutes, divide at the display site, not in the template:

```xml
<xsl:with-param name="val" select="$avgMin div 60"/>
<xsl:with-param name="unit">h</xsl:with-param>
```

Keeping the template in minutes means one source of truth for date math.

## Validation

Given two same-day timestamps 9 minutes apart, you should get `9.0`. Test against hand-calculated expected values before deploying:

```python
# From the rendered HTML
# bar: Create → Approve  val=8.9 min  n=4
# If source XML has CREATION_DATE=2026-04-19T22:00:00 and APPROVED_DATE=2026-04-19T22:09:00 for 4 reqs,
# expected avg = 9.0 min. Getting 8.9 means one of the APPROVED_DATEs is ~2 min earlier.
# Spot-check by computing manually.
```

Don't ship date math without at least one spot-checked value from real data.
