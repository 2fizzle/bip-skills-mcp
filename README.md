# bip-skills-mcp

MCP server that serves **Agent Skills** — folders containing a `SKILL.md` plus optional `references/`, `scripts/`, `assets/` — to any MCP client (Claude Desktop, Claude Code, Cursor, VS Code…).

It ships with one skill, **bip-xsl-hardening** (XSLT 1.0 patterns for Oracle BI Publisher HTML dashboards: locale-independent grouping, multi-shape XML, adaptive fallback, date arithmetic without EXSLT). Point `SKILLS_DIR` at your own folders to serve your private skills from your machine — they are never uploaded anywhere.

## Tools

| Tool | Purpose |
|---|---|
| `skills_list` | List skills (name, description, source). Optional `query` filter. |
| `skills_get` | Full `SKILL.md` of a skill. |
| `skills_list_files` | Bundled files of a skill with sizes. |
| `skills_read_file` | Read one text file of a skill (path-traversal protected, 2 MB max). |

Each skill is also exposed as a resource: `skill://<name>/SKILL.md`. All tools are read-only.

## Install

```json
{
  "mcpServers": {
    "skills": {
      "command": "npx",
      "args": ["-y", "@2fizzle/bip-skills-mcp"],
      "env": { "SKILLS_DIR": "C:\\path\\to\\my\\skills" }
    }
  }
}
```

| Variable | Effect |
|---|---|
| `SKILLS_DIR` | Extra skill folders, `;`-separated on Windows, `:` elsewhere. Searched up to 3 levels deep. A local skill overrides a bundled one with the same name. |
| `SKILLS_NO_BUNDLED=1` | Serve only `SKILLS_DIR`. |

Requires Node.js 20.3+.

## Develop

```bash
npm install
npm run build
npm run smoke   # starts the server and checks every tool
```

## License

MIT
