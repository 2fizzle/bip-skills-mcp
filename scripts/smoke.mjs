// Self-check: starts the built server over stdio and exercises every tool.
import { Client } from "@modelcontextprotocol/client";
import { StdioClientTransport } from "@modelcontextprotocol/client/stdio";

const client = new Client({ name: "smoke", version: "1.0.0" });
await client.connect(new StdioClientTransport({ command: process.execPath, args: ["dist/index.js"] }));
const fail = (m) => { console.error("FAIL:", m); process.exit(1); };
const text = (r) => r.content.map((c) => c.text).join("");

const tools = (await client.listTools()).tools.map((t) => t.name).sort();
console.log("tools:", tools.join(", "));
for (const t of ["skills_get", "skills_list", "skills_list_files", "skills_read_file"]) if (!tools.includes(t)) fail(`missing ${t}`);

const list = await client.callTool({ name: "skills_list", arguments: {} });
const names = list.structuredContent.skills.map((s) => s.name);
console.log("skills:", names.join(", "));
if (!names.length) fail("no skills");

const get = await client.callTool({ name: "skills_get", arguments: { name: names[0] } });
if (get.isError || !text(get).startsWith("---")) fail("skills_get");

const files = await client.callTool({ name: "skills_list_files", arguments: { name: names[0] } });
const first = files.structuredContent.files.find((f) => f.path.endsWith(".md") && f.path !== "SKILL.md");
const read = await client.callTool({ name: "skills_read_file", arguments: { name: names[0], path: first.path } });
if (read.isError) fail("skills_read_file");

const escape = await client.callTool({ name: "skills_read_file", arguments: { name: names[0], path: "../../package.json" } });
if (!escape.isError) fail("path traversal not blocked");
const unknown = await client.callTool({ name: "skills_get", arguments: { name: "nope" } });
if (!unknown.isError) fail("unknown skill not reported");

const res = await client.listResources();
console.log("resources:", res.resources.map((r) => r.uri).join(", "));
const rr = await client.readResource({ uri: res.resources[0].uri });
if (!rr.contents[0].text.startsWith("---")) fail("resource read");

console.log("OK — all checks passed");
await client.close();
