// Mints the synthetic solo license the smoke suite validates against.
//
//   node scripts/mint-smoke-solo.ts            # production
//   API=http://127.0.0.1:8787 node scripts/mint-smoke-solo.ts   # local dev
//
// The key is written to C:\Users\HP\.practicum\smoke_solo_key (BOM-free, no
// trailing newline) and is never printed. Re-running replaces the same record
// rather than accumulating keys — the order id is stable.
//
// No customer key is ever used as a fixture, and DODO_WEBHOOK_SECRET is not
// involved: the worker mints this through the same buildLicenseRecord() the
// Dodo webhook uses, behind the X-Smoke-Secret header. The record carries
// is_test, so countableLicense() keeps it out of customer and revenue counts.

import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";

const API = (process.env.API ?? "https://api.practicum-cli.dev").replace(/\/$/, "");
const KEY_FILE = process.env.SMOKE_SOLO_KEY_FILE ?? "C:\\Users\\HP\\.practicum\\smoke_solo_key";
const SECRET_FILE = process.env.SMOKE_TOKEN_SECRET_FILE ?? "C:\\Users\\HP\\.practicum\\smoke_token_secret";

const secret = (process.env.SMOKE_TOKEN_SECRET ?? readFileSync(SECRET_FILE, "utf8")).trim();
if (!secret) {
  console.error(`No smoke secret. Set SMOKE_TOKEN_SECRET or write it to ${SECRET_FILE}.`);
  process.exit(2);
}

const res = await fetch(`${API}/v1/admin/mint-smoke-solo`, {
  method: "POST",
  headers: { "X-Smoke-Secret": secret, "Content-Type": "application/x-www-form-urlencoded" },
});

if (!res.ok) {
  console.error(`Mint failed: HTTP ${res.status}. A 404 means the secret did not match.`);
  process.exit(1);
}

const body = (await res.json()) as { key: string; email: string; entitlements: string[]; expires_at: string };

mkdirSync(dirname(KEY_FILE), { recursive: true });
writeFileSync(KEY_FILE, body.key, { encoding: "utf8" });   // no BOM, no trailing newline

console.log("Smoke solo license minted.");
console.log(`  written to   ${KEY_FILE}`);
console.log(`  email        ${body.email}`);
console.log(`  entitlements ${body.entitlements.join(", ")}`);
console.log(`  expires      ${body.expires_at.slice(0, 10)}`);
console.log("  key          (not printed — read from the file above)");
