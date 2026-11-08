#!/usr/bin/env python3
"""
Render a BIP HTML XSL against one or more XML inputs and extract the
key visual values (bar values, panel headings) for verification.

Usage:
    python render_and_inspect.py <xsl_path> <xml_path> [<xml_path> ...]

For each XML input, prints:
    - Rendered preview file path
    - All <h2> headings in document order
    - All bar-row entries with label/n/value/unit

Use this after every patch to confirm:
    1. The XSL still parses (syntax check).
    2. Each adaptive branch reaches the expected XML input.
    3. Bar values match hand-calculated expectations.
"""

import re
import sys
from pathlib import Path

from lxml import etree


def render(xsl_path: Path, xml_path: Path, out_dir: Path) -> Path:
    """Transform xml with xsl and write the HTML output. Returns the output path."""
    xsl = etree.XSLT(etree.parse(str(xsl_path)))
    parser = etree.XMLParser(recover=True)  # tolerate truncated uploads
    xml = etree.parse(str(xml_path), parser)
    result = xsl(xml)
    out = out_dir / f"preview_{xml_path.stem}.html"
    out.write_bytes(bytes(result))
    return out


def inspect(html_path: Path) -> None:
    html = html_path.read_text()
    headings = re.findall(r"<h2>([^<]+)</h2>", html)
    bars = re.findall(
        r'<div class="bar-row">\s*<div class="lbl">([^<]+)<span class="n">n=(\d+)</span>.*?<div class="val">\s*([-\d.]+)\s*<span>([^<]*)</span>',
        html,
        re.DOTALL,
    )
    print(f"\n=== {html_path.name} ===")
    print(f"Headings ({len(headings)}):")
    for h in headings:
        print(f"  - {h}")
    print(f"Bars ({len(bars)}):")
    for label, n, val, unit in bars:
        print(f"  - {label.strip():<30} n={n:>4}  {val:>8} {unit.strip()}")


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 1
    xsl_path = Path(argv[1])
    xml_paths = [Path(p) for p in argv[2:]]
    out_dir = xsl_path.parent
    for xml_path in xml_paths:
        try:
            html_path = render(xsl_path, xml_path, out_dir)
        except etree.XSLTApplyError as e:
            print(f"TRANSFORM FAILED for {xml_path}: {e}", file=sys.stderr)
            continue
        except etree.XMLSyntaxError as e:
            print(f"XML PARSE FAILED for {xml_path}: {e}", file=sys.stderr)
            continue
        print(f"WROTE {html_path}")
        inspect(html_path)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
