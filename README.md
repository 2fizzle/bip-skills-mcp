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

## Remote use (Streamable HTTP)

Set `TRANSPORT=http` to serve MCP over HTTP at `/mcp` (health check at `/health`).

| Variable | Default | Effect |
|---|---|---|
| `TRANSPORT` | `stdio` | `http` turns on the HTTP server. |
| `PORT` | `3000` | Listening port. |
| `HOST` | `127.0.0.1`, or `0.0.0.0` when `PORT` is set by the host | Bind address. |
| `ALLOWED_HOSTS` | — | Comma-separated public host names accepted in the `Host` header when binding `0.0.0.0` (DNS-rebinding protection). |
| `MCP_AUTH_TOKEN` | — | If set, every `/mcp` request must send `Authorization: Bearer <token>`. Leave unset only if the served skills are public. |

Run locally:

```bash
TRANSPORT=http npx -y @2fizzle/bip-skills-mcp
# → http://127.0.0.1:3000/mcp
```

### Deploy

- **Render**: New → Blueprint → this repository (uses `render.yaml`). Set `MCP_AUTH_TOKEN` in the dashboard if you want a token, and change `ALLOWED_HOSTS` to your service host name.
- **Any Docker host** (Fly.io, Railway, Cloud Run…): `docker build -t bip-skills-mcp .` then run with `-p 3000:3000 -e ALLOWED_HOSTS=your.host`.

A hosted instance only serves the bundled skills: `SKILLS_DIR` points to a local folder and has no effect there.

### Connect

- **Claude (web, desktop, mobile)**: Settings → Connectors → Add custom connector → `https://<your-host>/mcp`. Custom connectors support no-auth or OAuth servers, not static bearer tokens — leave `MCP_AUTH_TOKEN` unset for this route.
- **Claude Code**: `claude mcp add --transport http bip-skills https://<your-host>/mcp --header "Authorization: Bearer <token>"`

## Develop

```bash
npm install
npm run build
npm run smoke        # stdio: starts the server and checks every tool
npm run smoke:http   # HTTP: checks /health, bearer auth and every tool
```

## License

MIT
