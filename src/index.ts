#!/usr/bin/env node
/**
 * bip-skills-mcp — serves Agent Skills folders (SKILL.md + bundled files) over MCP (stdio).
 * Skill roots: the bundled ./skills folder, plus SKILLS_DIR (';' or ':' separated).
 */
import { McpServer, ResourceTemplate, ProtocolError, ProtocolErrorCode } from "@modelcontextprotocol/server";
import { serveStdio } from "@modelcontextprotocol/server/stdio";
import { createMcpHandler } from "@modelcontextprotocol/server";
import { createMcpExpressApp } from "@modelcontextprotocol/express";
import { toNodeHandler } from "@modelcontextprotocol/node";
import { timingSafeEqual } from "node:crypto";
import * as z from "zod/v4";
import { promises as fs } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";

const VERSION = "1.1.0";
const CHARACTER_LIMIT = 25_000;
const MAX_FILE_BYTES = 2_000_000;
const TEXT_EXT = new Set([
  ".md", ".txt", ".json", ".xml", ".xsl", ".xslt", ".html", ".htm", ".css", ".js", ".mjs", ".ts",
  ".py", ".sql", ".yaml", ".yml", ".csv", ".svg", ".sh", ".jsx", ".tsx", ".ini", ".toml"
]);

const here = path.dirname(fileURLToPath(import.meta.url));
const BUNDLED = path.resolve(here, "..", "skills");

interface Skill { name: string; description: string; dir: string; source: "bundled" | "local"; }

function roots(): { dir: string; source: Skill["source"] }[] {
  const out: { dir: string; source: Skill["source"] }[] = [];
  if (process.env.SKILLS_NO_BUNDLED !== "1") out.push({ dir: BUNDLED, source: "bundled" });
  const extra = process.env.SKILLS_DIR;
  if (extra) {
    const sep = extra.includes(";") || process.platform === "win32" ? ";" : ":";
    for (const d of extra.split(sep).map((s) => s.trim()).filter(Boolean)) out.push({ dir: path.resolve(d), source: "local" });
  }
  return out;
}

function frontmatter(text: string): Record<string, unknown> {
  const m = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text);
  if (!m) return {};
  try { const y = parseYaml(m[1]); return y && typeof y === "object" ? (y as Record<string, unknown>) : {}; }
  catch { return {}; }
}

async function findSkillDirs(root: string, depth = 0): Promise<string[]> {
  if (depth > 3) return [];
  let entries;
  try { entries = await fs.readdir(root, { withFileTypes: true }); } catch { return []; }
  if (entries.some((e) => e.isFile() && e.name.toLowerCase() === "skill.md")) return [root];
  const out: string[] = [];
  for (const e of entries) {
    if (e.isDirectory() && !e.name.startsWith(".") && e.name !== "node_modules") out.push(...(await findSkillDirs(path.join(root, e.name), depth + 1)));
  }
  return out;
}

async function loadSkills(): Promise<Map<string, Skill>> {
  const map = new Map<string, Skill>();
  for (const { dir, source } of roots()) {
    for (const d of await findSkillDirs(dir)) {
      const files = await fs.readdir(d);
      const f = files.find((n) => n.toLowerCase() === "skill.md")!;
      const fm = frontmatter(await fs.readFile(path.join(d, f), "utf8"));
      const name = String(fm.name ?? path.basename(d)).trim();
      const description = String(fm.description ?? "").replace(/\s+/g, " ").trim();
      map.set(name, { name, description, dir: d, source }); // later roots override earlier ones
    }
  }
  return map;
}

async function getSkill(name: string): Promise<Skill> {
  const skills = await loadSkills();
  const s = skills.get(name);
  if (!s) throw new Error(`Unknown skill "${name}". Call skills_list to see available names. Available: ${[...skills.keys()].join(", ") || "(none)"}`);
  return s;
}

function safeJoin(base: string, rel: string): string {
  const full = path.resolve(base, rel);
  const b = path.resolve(base) + path.sep;
  if (full !== path.resolve(base) && !full.startsWith(b)) throw new Error(`Path "${rel}" is outside the skill folder. Use a relative path from skills_list_files.`);
  return full;
}

async function walk(dir: string, base = dir): Promise<{ path: string; bytes: number }[]> {
  const out: { path: string; bytes: number }[] = [];
  for (const e of await fs.readdir(dir, { withFileTypes: true })) {
    if (e.name.startsWith(".")) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out.push(...(await walk(p, base)));
    else if (e.isFile()) out.push({ path: path.relative(base, p).split(path.sep).join("/"), bytes: (await fs.stat(p)).size });
  }
  return out.sort((a, b) => a.path.localeCompare(b.path));
}

function page(text: string, offset: number): string {
  const chunk = text.slice(offset, offset + CHARACTER_LIMIT);
  const next = offset + chunk.length;
  return next < text.length ? `${chunk}\n\n[Truncated: ${text.length - next} more characters. Call again with offset=${next}.]` : chunk;
}

function createServer(): McpServer {
  const server = new McpServer({ name: "bip-skills-mcp", version: VERSION });

  server.registerTool("skills_list", {
    title: "List skills",
    description: "List every available Agent Skill with its name, description and source (bundled or local). Call this first, pick the skill whose description matches the task, then call skills_get with its name.",
    inputSchema: z.strictObject({
      query: z.string().max(200).optional().describe("Optional text to filter skills by name or description, e.g. 'xsl' or 'oracle'")
    }),
    annotations: { readOnlyHint: true, idempotentHint: true, openWorldHint: false }
  }, async ({ query }) => {
    let skills = [...(await loadSkills()).values()];
    if (query) { const q = query.toLowerCase(); skills = skills.filter((s) => (s.name + " " + s.description).toLowerCase().includes(q)); }
    const items = skills.map(({ name, description, source }) => ({ name, description, source }));
    const text = items.length
      ? items.map((s) => `- **${s.name}** (${s.source}): ${s.description}`).join("\n")
      : "No skill found. Check SKILLS_DIR, or call without query.";
    return { content: [{ type: "text", text }], structuredContent: { count: items.length, skills: items } };
  });

  server.registerTool("skills_get", {
    title: "Get skill instructions",
    description: "Return the full SKILL.md of one skill (frontmatter + instructions). Follow those instructions for the task. Paths it mentions (references/..., scripts/..., assets/...) can be read with skills_read_file.",
    inputSchema: z.strictObject({
      name: z.string().min(1).describe("Skill name as returned by skills_list, e.g. 'bip-xsl-hardening'"),
      offset: z.number().int().min(0).default(0).describe("Character offset for long skills; use the value given in a truncation note")
    }),
    annotations: { readOnlyHint: true, idempotentHint: true, openWorldHint: false }
  }, async ({ name, offset }) => {
    const s = await getSkill(name);
    const f = (await fs.readdir(s.dir)).find((n) => n.toLowerCase() === "skill.md")!;
    const text = await fs.readFile(path.join(s.dir, f), "utf8");
    return { content: [{ type: "text", text: page(text, offset) }] };
  });

  server.registerTool("skills_list_files", {
    title: "List skill files",
    description: "List the bundled files of one skill (references, scripts, assets, evals) with their sizes. Use the returned relative paths with skills_read_file.",
    inputSchema: z.strictObject({ name: z.string().min(1).describe("Skill name as returned by skills_list") }),
    annotations: { readOnlyHint: true, idempotentHint: true, openWorldHint: false }
  }, async ({ name }) => {
    const s = await getSkill(name);
    const files = await walk(s.dir);
    const text = files.map((f) => `- ${f.path} (${f.bytes} bytes)`).join("\n");
    return { content: [{ type: "text", text }], structuredContent: { skill: name, files } };
  });

  server.registerTool("skills_read_file", {
    title: "Read a skill file",
    description: "Read one text file bundled with a skill, by its relative path (from skills_list_files), e.g. 'references/adaptive-fallback.md'. Binary files are not returned.",
    inputSchema: z.strictObject({
      name: z.string().min(1).describe("Skill name as returned by skills_list"),
      path: z.string().min(1).max(500).describe("Relative file path inside the skill, e.g. 'scripts/render_and_inspect.py'"),
      offset: z.number().int().min(0).default(0).describe("Character offset for long files; use the value given in a truncation note")
    }),
    annotations: { readOnlyHint: true, idempotentHint: true, openWorldHint: false }
  }, async ({ name, path: rel, offset }) => {
    const s = await getSkill(name);
    const full = safeJoin(s.dir, rel);
    let st;
    try { st = await fs.stat(full); } catch { throw new Error(`File "${rel}" not found in skill "${name}". Call skills_list_files to see valid paths.`); }
    if (!st.isFile()) throw new Error(`"${rel}" is a folder. Call skills_list_files to see the files inside.`);
    if (!TEXT_EXT.has(path.extname(full).toLowerCase())) throw new Error(`"${rel}" is not a text file (${path.extname(full) || "no extension"}); it cannot be returned.`);
    if (st.size > MAX_FILE_BYTES) throw new Error(`"${rel}" is ${st.size} bytes, above the ${MAX_FILE_BYTES}-byte limit.`);
    const text = await fs.readFile(full, "utf8");
    return { content: [{ type: "text", text: page(text, offset) }] };
  });

  server.registerResource("skill", new ResourceTemplate("skill://{name}/SKILL.md", {
    list: async () => ({
      resources: [...(await loadSkills()).values()].map((s) => ({ uri: `skill://${s.name}/SKILL.md`, name: s.name, description: s.description, mimeType: "text/markdown" }))
    })
  }), { title: "Skill instructions", description: "SKILL.md of an Agent Skill", mimeType: "text/markdown" },
  async (uri, { name }) => {
    const s = (await loadSkills()).get(String(name));
    if (!s) throw new ProtocolError(ProtocolErrorCode.ResourceNotFound ?? ProtocolErrorCode.InvalidParams, `Unknown skill ${name}`);
    const f = (await fs.readdir(s.dir)).find((n) => n.toLowerCase() === "skill.md")!;
    return { contents: [{ uri: uri.href, mimeType: "text/markdown", text: await fs.readFile(path.join(s.dir, f), "utf8") }] };
  });

  return server;
}

// ---- Transport selection: stdio by default, Streamable HTTP when TRANSPORT=http ----

function tokenMatches(given: string, expected: string): boolean {
  const a = Buffer.from(given), b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

if (process.env.TRANSPORT === "http") {
  const port = Number(process.env.PORT ?? 3000);
  const host = process.env.HOST ?? (process.env.PORT ? "0.0.0.0" : "127.0.0.1");
  const allowedHosts = (process.env.ALLOWED_HOSTS ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const authToken = process.env.MCP_AUTH_TOKEN;

  const app = createMcpExpressApp(host === "127.0.0.1" || host === "localhost" ? {} : { host, ...(allowedHosts.length ? { allowedHosts } : {}) });
  const nodeHandler = toNodeHandler(createMcpHandler(createServer));

  app.get("/health", (_req, res) => { res.json({ status: "ok", name: "bip-skills-mcp", version: VERSION }); });
  app.all("/mcp", (req, res) => {
    if (authToken) {
      const header = req.headers.authorization ?? "";
      const given = header.startsWith("Bearer ") ? header.slice(7) : "";
      if (!tokenMatches(given, authToken)) {
        res.status(401).set("WWW-Authenticate", "Bearer").json({ error: "unauthorized", message: "Send Authorization: Bearer <MCP_AUTH_TOKEN>" });
        return;
      }
    }
    void nodeHandler(req, res, req.body);
  });

  app.listen(port, host, () => {
    console.error(`bip-skills-mcp ${VERSION} listening on http://${host}:${port}/mcp${authToken ? " (bearer token required)" : " (no auth)"}`);
  });
} else {
  serveStdio(createServer);
  console.error(`bip-skills-mcp ${VERSION} running on stdio`);
}
