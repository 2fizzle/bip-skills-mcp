# Multi-Shape XML Support

## The problem

The same logical data — say "CSP history events" in Oracle HCM — appears at different XML depths depending on which BIP data model produced the extract:

- **Requisitions data model**: events nested under submissions → `/DATA_DS/G_1/G_2/G_14`
- **Standalone CSP history data model**: events at root → `/DATA_DS/G_1[HISTORY_EVENT_ID]`

Don't ship two stylesheets. Write one that handles both.

## The pattern: union xpath everywhere

### Root data variable

```xml
<xsl:variable name="csp" select="/DATA_DS/G_1/G_2/G_14 | /DATA_DS/G_1[HISTORY_EVENT_ID]"/>
```

The `|` operator takes the union of two node-sets. Each source is qualified by a distinguishing predicate — in the second path, `HISTORY_EVENT_ID` exists only on standalone-CSP-shape rows, so it disambiguates from regular requisition rows.

### Keys

Keys match patterns, not paths, but the pattern can still use the same disambiguating predicates:

```xml
<xsl:key name="byPhase"
         match="G_14[SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) > 0]
              | G_1[HISTORY_EVENT_ID and SOURCE_OBJECT_ID='1' and EVENT_TYPE_CODE='PHASE_COMPLETION' and string-length(PHASE_CODE) > 0]"
         use="PHASE_CODE"/>
```

The key now indexes rows from both shapes under the same bucket.

### Predicate-based discrimination

Pick a field that exists on exactly one shape. In the example above, `HISTORY_EVENT_ID` only appears at root-level `G_1` rows in the standalone extract — regular requisition rows in `G_1` have `REQUISITION_ID` but not `HISTORY_EVENT_ID`.

When you're looking for a discriminator, grep the real XML files. Anything that's reliably present on shape A and absent on shape B works.

## Field-name coalesce

Even within one shape, the same date can appear under different column names. In the CSP example:

- Nested `G_14` shape uses `EVENT_OCCURRED_DATE`.
- Root `G_1[HISTORY_EVENT_ID]` shape uses `TRANSITION_DATE`.

There's no `coalesce()` in XSLT 1.0, but `concat` is a stand-in because an empty element string-converts to `""`:

```xml
<xsl:variable name="ym" select="substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE), 1, 7)"/>
```

If `EVENT_OCCURRED_DATE` is `"2026-04-19T22:27:55..."` and `TRANSITION_DATE` is empty, `concat` gives `"2026-04-19T22:27:55..."`. If it's the other way around, you get `TRANSITION_DATE`. Exactly one is non-empty, so concat is safe.

This only works when the two fields are mutually exclusive. If both could be populated you'd get them concatenated together and the substring would slice across the boundary. Verify against real XML.

### Apply the same coalesce inside keys

Any key that uses a date column has to coalesce the same way:

```xml
<xsl:key name="cspMonth"
         match="G_14 | G_1[HISTORY_EVENT_ID]"
         use="substring(concat(EVENT_OCCURRED_DATE, TRANSITION_DATE), 1, 7)"/>
```

## Validating across shapes

Keep one representative XML per shape. Render the XSL against every one:

```python
for name, path in [('REQS', 'reqs.xml'), ('CSP_HISTORY', 'csp_history.xml')]:
    result = transform(etree.parse(path, etree.XMLParser(recover=True)))
    open(f'preview_{name}.html', 'wb').write(bytes(result))
```

If either preview drops to zero counts or shows empty-state, something about your predicates is still shape-specific. The most common mistake is forgetting to add the `G_1[HISTORY_EVENT_ID]` arm to one of the keys.

## When shapes truly diverge

Sometimes one shape carries data the other doesn't (e.g. requisition extract has `G_1/CREATION_DATE` but CSP history doesn't have any requisition-level columns). Don't try to unify — use the adaptive-fallback pattern to detect which shape you're looking at and render a different view per shape. See `adaptive-fallback.md`.
