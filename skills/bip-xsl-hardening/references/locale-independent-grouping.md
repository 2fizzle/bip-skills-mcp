# Locale-Independent Grouping (Muenchian on Code Fields)

## The problem

Oracle HCM data models expose two columns for most categorical fields: a `*_CODE` (stable identifier) and a `*_NAME` (user-facing display string, localized to the runtime user's locale).

Stylesheets written in English-only environments tend to filter on `*_NAME`:

```xml
<!-- BAD: breaks in French, Spanish, etc. -->
<xsl:variable name="posting" select="$csp[PHASE_NAME='Job formatting']"/>
```

When the same XSL runs in a French tenant, `PHASE_NAME` contains `"Mise en forme de l'emploi"` and the filter returns nothing. Bars render at zero. The dashboard appears broken.

## The fix

Filter on `*_CODE`. Use `*_NAME` only for display.

```xml
<xsl:variable name="posting" select="$csp[PHASE_CODE='JOB_POSTING']"/>
```

For dynamic grouping across an unknown set of values (you don't know at design time how many phases exist), use Muenchian grouping keyed on the code:

```xml
<xsl:key name="byPhase"
         match="G_14[EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) > 0]"
         use="PHASE_CODE"/>

<xsl:variable name="allPhases"
              select="$csp[EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) > 0]"/>

<xsl:variable name="distinctPhases"
              select="$allPhases[count(. | key('byPhase', PHASE_CODE)[1]) = 1]"/>

<xsl:for-each select="$distinctPhases">
  <xsl:sort select="sum(key('byPhase', PHASE_CODE)/STEP_DURATION) div count(key('byPhase', PHASE_CODE))"
            data-type="number" order="descending"/>
  <xsl:variable name="grp" select="key('byPhase', PHASE_CODE)"/>
  <div class="bar">
    <span class="label"><xsl:value-of select="PHASE_NAME"/></span>
    <span class="value">
      <xsl:value-of select="format-number(sum($grp/STEP_DURATION) div count($grp), '0.0')"/>
    </span>
  </div>
</xsl:for-each>
```

## How Muenchian grouping works

The predicate `count(. | key('byPhase', PHASE_CODE)[1]) = 1` is an idiom, not a computation.

- `key('byPhase', PHASE_CODE)` returns every node in the same group as the current node (same `PHASE_CODE`).
- `key('byPhase', PHASE_CODE)[1]` is the first node in that group (document order).
- `.` is the current node.
- `. | key(...)[1]` is the union of the current node and the first group member.
- That union has 1 member if-and-only-if the current node IS the first in its group.

So `$allPhases[count(. | key('byPhase', PHASE_CODE)[1]) = 1]` returns exactly one representative per distinct `PHASE_CODE` — the first occurrence. These representative nodes carry the `PHASE_NAME` the user should see, and `key('byPhase', PHASE_CODE)` lets you retrieve the full group for aggregation.

## Why not just `preceding-sibling`?

In XSLT 1.0, `preceding-sibling` and `preceding` are O(n²) for grouping — for every node, you scan every earlier node. Muenchian grouping uses a key index, which is O(n). On a BIP report with thousands of rows this difference is between "instant" and "timeout".

## Filtering for meaningful groups

Always filter out rows with empty codes *before* Muenchian grouping. Otherwise the empty-string group becomes one of your "distinct phases" and renders as a blank bar:

```xml
<xsl:variable name="allPhases"
              select="$csp[EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) > 0]"/>
```

Always put the filter on BOTH the key match pattern AND the variable selection. Otherwise the key and the distinct selector disagree about which nodes exist.

## Multi-dimension grouping

To group by two fields (say `PHASE_CODE` and `STATE_CODE`), concatenate in the key:

```xml
<xsl:key name="byPhaseState" match="G_14" use="concat(PHASE_CODE, '|', STATE_CODE)"/>
<xsl:variable name="distinct" select="$rows[count(. | key('byPhaseState', concat(PHASE_CODE, '|', STATE_CODE))[1]) = 1]"/>
```

Use a separator that cannot appear in either code (`|`, `\x01`, etc.).
