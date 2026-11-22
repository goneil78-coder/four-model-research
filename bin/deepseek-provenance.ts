#!/usr/bin/env bun
// Traces every URL in a DeepSeek lane report to the search results DeepSeek
// actually received. Reads ONLY the search records in the raw API responses
// (.choices[0].message.server_tool_calls[].calls[].sources[].url), never the
// generated answer: a link the model wrote from memory must not vouch for itself.
//
// Usage: deepseek-provenance.ts <report.md> <raw.json> [raw2.json ...]
// One line per URL in the report:
//   TRACED      this exact page came back in a search result
//   BARE-SITE   a site's home page only; says nothing about which page was used
//   UNTRACED    not in any search result (or unparseable): treat as from memory
// Exit: 0 all traced | 1 any BARE-SITE or UNTRACED | 2 usage or input error
//
// Matching rules (round-2 review, 22 Nov 2026): host is case-insensitive and
// ignores "www."; path keeps its case; percent-escapes are decoded except
// reserved delimiters and control characters; the fragment is dropped; the
// query is kept, minus tracking/bot-check parameters. A report URL with no
// query may match a source with one (search engines append session params);
// a report URL WITH a query must match exactly. Parent and child paths never
// count as the same page.

const die = (msg: string): never => { console.error(msg); process.exit(2); };

process.on("uncaughtException", (e) => die(`input error: ${(e as Error).message}`));
process.on("unhandledRejection", (e) => die(`input error: ${String(e)}`));

const [reportPath, ...rawPaths] = process.argv.slice(2);
if (!reportPath || rawPaths.length === 0) die("usage: deepseek-provenance.ts <report.md> <raw.json> [raw2.json ...]");

const TRACKING = /^(utm_|__cf_chl|_x_output_type|fbclid$|gclid$|spm$|from$|ref$)/i;

function decodeSafe(path: string): string {
  // Decode %HH except reserved delimiters (/ ? # % and friends) and controls.
  return path.replace(/%([0-9A-Fa-f]{2})/g, (m, h) => {
    const c = parseInt(h, 16);
    if (c < 0x20 || c === 0x7f) return m.toUpperCase();
    const ch = String.fromCharCode(c);
    if ("/?#[]@!$&'()*+,;=%".includes(ch)) return m.toUpperCase();
    return ch;
  }).replace(/(%[0-9A-Fa-f]{2})+/g, (run) => {
    // multi-byte UTF-8 sequences (e.g. Chinese) decode as a unit
    try {
      const s = decodeURIComponent(run);
      // keep encoded if decoding would create a control char or a reserved delimiter
      return /[\x00-\x1f\x7f\/?#\[\]@!$&'()*+,;=%]/.test(s) ? run.toUpperCase() : s;
    }
    catch { return run.toUpperCase(); }
  });
}

type Key = { host: string; path: string; query: string; root: boolean };
function keyOf(raw: string): Key | null {
  let u: URL;
  try { u = new URL(raw); } catch { return null; }
  if (u.protocol !== "http:" && u.protocol !== "https:") return null;
  // u.host keeps a non-default port: different ports can be different services.
  const host = u.host.toLowerCase().replace(/^www\./, "");
  const path = decodeSafe(u.pathname).replace(/\/+$/, "");
  const params = [...u.searchParams.entries()].filter(([k]) => !TRACKING.test(k))
    .sort(([a], [b]) => a.localeCompare(b));
  const query = params.length ? JSON.stringify(params) : "";   // unambiguous: a=1%26b%3D2 ≠ a=1&b=2
  return { host, path, query, root: path === "" && query === "" };
}

// ---- load search records; any bad input is exit 2, never a silent pass ----
const exact = new Set<string>(), noQuery = new Set<string>(), hosts = new Set<string>();
let sourceCount = 0;
for (const p of rawPaths) {
  const f = Bun.file(p);
  if (!(await f.exists())) die(`no such raw response: ${p}`);
  let j: any;
  try { j = JSON.parse(await f.text()); } catch { die(`not valid JSON: ${p}`); }
  const calls = j?.choices?.[0]?.message?.server_tool_calls;
  if (!Array.isArray(calls)) die(`no server_tool_calls in ${p} (not a searched DeepSeek response?)`);
  for (const group of calls) {
    const cs = group?.calls ?? [];
    if (!Array.isArray(cs)) die(`malformed calls in ${p}`);
    for (const call of cs) {
    const srcs = call?.sources ?? [];
    if (!Array.isArray(srcs)) die(`malformed sources in ${p}`);
    for (const s of srcs) {
    if (typeof s?.url !== "string") continue;
    const k = keyOf(s.url); if (!k) continue;
    sourceCount++;
    exact.add(`${k.host}${k.path}?${k.query}`);
    noQuery.add(`${k.host}${k.path}`);
    hosts.add(k.host);
  }}}
}
if (sourceCount === 0) die("search records contain no source URLs; cannot trace anything");

const rf = Bun.file(reportPath);
if (!(await rf.exists())) die(`no such report: ${reportPath}`);
const report = await rf.text();
// Commas and asterisks are valid inside URLs; only strip them when trailing
// (prose "URL, date" and markdown "**URL**").
const urls = [...new Set((report.match(/https?:\/\/[^\s)<>\]"]+/g) ?? []).map((u) => u.replace(/[.,;:*]+$/, "")))].sort();

let t = 0, b = 0, un = 0;
for (const u of urls) {
  const k = keyOf(u);
  let tag: string;
  if (!k) { tag = "UNTRACED  "; un++; }
  else if (k.root) { if (hosts.has(k.host)) { tag = "BARE-SITE "; b++; } else { tag = "UNTRACED  "; un++; } }
  else if (exact.has(`${k.host}${k.path}?${k.query}`) || (k.query === "" && noQuery.has(`${k.host}${k.path}`))) { tag = "TRACED    "; t++; }
  else { tag = "UNTRACED  "; un++; }
  console.log(`${tag} ${u}`);
}
console.log("---");
console.log(`traced ${t} | bare site name ${b} | untraced ${un}   (${sourceCount} search-result URLs across ${rawPaths.length} raw file(s))`);
process.exit(b === 0 && un === 0 ? 0 : 1);
