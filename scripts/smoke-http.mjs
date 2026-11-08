// Self-check for HTTP mode: starts the server with TRANSPORT=http and exercises auth + tools.
import { spawn } from "node:child_process";
import { Client, StreamableHTTPClientTransport } from "@modelcontextprotocol/client";

const PORT = 3917, TOKEN = "smoke-test-token";
const url = new URL(`http://127.0.0.1:${PORT}/mcp`);
const srv = spawn(process.execPath, ["dist/index.js"], { env: { ...process.env, TRANSPORT: "http", HOST: "127.0.0.1", PORT: String(PORT), MCP_AUTH_TOKEN: TOKEN }, stdio: ["ignore", "ignore", "pipe"] });
await new Promise((ok, ko) => { srv.stderr.on("data", (d) => String(d).includes("listening") && ok()); setTimeout(() => ko(new Error("server did not start")), 10000); });
const fail = (m) => { console.error("FAIL:", m); srv.kill(); process.exit(1); };
try {
  const health = await (await fetch(`http://127.0.0.1:${PORT}/health`)).json();
  console.log("health:", JSON.stringify(health));
  const noAuth = await fetch(url, { method: "POST", headers: { "content-type": "application/json", accept: "application/json, text/event-stream" }, body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }) });
  if (noAuth.status !== 401) fail(`expected 401 without token, got ${noAuth.status}`);
  console.log("no token -> 401");
  const client = new Client({ name: "smoke-http", version: "1.0.0" });
  await client.connect(new StreamableHTTPClientTransport(url, { requestInit: { headers: { Authorization: `Bearer ${TOKEN}` } } }));
  const tools = (await client.listTools()).tools.map((t) => t.name).sort();
  console.log("tools:", tools.join(", "));
  const list = await client.callTool({ name: "skills_list", arguments: {} });
  console.log("skills:", list.structuredContent.skills.map((s) => s.name).join(", "));
  const get = await client.callTool({ name: "skills_get", arguments: { name: "bip-xsl-hardening" } });
  if (get.isError) fail("skills_get");
  await client.close();
  console.log("OK — HTTP checks passed");
} catch (e) { fail(e?.message ?? e); }
srv.kill();
