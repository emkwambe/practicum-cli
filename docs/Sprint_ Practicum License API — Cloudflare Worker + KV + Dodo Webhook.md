\# Sprint: Practicum License API — Cloudflare Worker \+ KV \+ Dodo Webhook

&nbsp;

\#\# Context

\- Repo: github.com/emkwambe/practicum-cli

\- Live site Worker: blue-pine-8359 (practicum-cli.dev) — static assets only, untouched

\- New Worker: practicum-api — handles license generation, validation, and Dodo webhook

\- Cloudflare account: Mpingo Systems LLC

\- Dodo Payments: 13 products live, webhook support available

\- Current license system: self-asserted \~/.practicum/license.json — being replaced

\- Audit gaps this closes: items 1, 2, 3 (content gating, self-asserted file, per-product entitlement)

&nbsp;

\---

&nbsp;

\#\# Architecture

&nbsp;

\`\`\`

Buyer pays on Dodo

&nbsp;&nbsp;→ Dodo fires POST to https://api.practicum-cli.dev/webhooks/dodo

&nbsp;&nbsp;→ Worker verifies Dodo webhook signature

&nbsp;&nbsp;→ Worker generates unique license key (HMAC-SHA256)

&nbsp;&nbsp;→ Worker stores key in KV: key → {email, product\_id, entitlements, activated: false}

&nbsp;&nbsp;→ Worker sends license key email via Resend

&nbsp;&nbsp;→ Learner runs: practicum license activate \<key\>

&nbsp;&nbsp;→ CLI calls GET https://api.practicum-cli.dev/license/validate?key=\<key\>

&nbsp;&nbsp;→ Worker looks up key in KV → returns entitlements JSON

&nbsp;&nbsp;→ CLI writes \~/.practicum/license.json with server response \+ expiry timestamp

&nbsp;&nbsp;→ Daily revalidation: CLI calls validate on first command of the day

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 1 — Scaffold the API Worker

&nbsp;

Create a new directory in the repo:

&nbsp;

\`\`\`

workers/

└── practicum-api/

&nbsp;&nbsp;&nbsp;&nbsp;├── wrangler.toml

&nbsp;&nbsp;&nbsp;&nbsp;├── src/

&nbsp;&nbsp;&nbsp;&nbsp;│   └── index.ts

&nbsp;&nbsp;&nbsp;&nbsp;├── package.json

&nbsp;&nbsp;&nbsp;&nbsp;└── tsconfig.json

\`\`\`

&nbsp;

\`workers/practicum-api/wrangler.toml\`:

&nbsp;

\`\`\`toml

name \= "practicum-api"

main \= "src/index.ts"

compatibility\_date \= "2024-01-01"

&nbsp;

\[\[kv\_namespaces\]\]

binding \= "LICENSES"

id \= ""        \# fill after: wrangler kv namespace create LICENSES

&nbsp;

\[\[kv\_namespaces\]\]

binding \= "ORDERS"

id \= ""        \# fill after: wrangler kv namespace create ORDERS

&nbsp;

\[vars\]

ENVIRONMENT \= "production"

&nbsp;

\# Secrets (set via wrangler secret put, never in toml):

\# DODO\_WEBHOOK\_SECRET

\# HMAC\_SECRET

\# RESEND\_API\_KEY

\`\`\`

&nbsp;

Create the KV namespaces:

&nbsp;

\`\`\`powershell

wrangler kv namespace create LICENSES \--cwd workers/practicum-api

wrangler kv namespace create ORDERS \--cwd workers/practicum-api

\`\`\`

&nbsp;

Paste the returned IDs into wrangler.toml.

&nbsp;

Set secrets:

&nbsp;

\`\`\`powershell

wrangler secret put DODO\_WEBHOOK\_SECRET \--cwd workers/practicum-api

wrangler secret put HMAC\_SECRET \--cwd workers/practicum-api

wrangler secret put RESEND\_API\_KEY \--cwd workers/practicum-api

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 2 — Product → Entitlement Map

&nbsp;

In \`src/index.ts\`, define the entitlement map using the exact Dodo product IDs:

&nbsp;

\`\`\`typescript

const PRODUCT\_ENTITLEMENTS: Record\<string, string\[\]\> \= {

&nbsp;&nbsp;// Single courses

&nbsp;&nbsp;"pdt\_0No7umC6gaGIE4EXLu2Gu": \["linux-foundations"\],

&nbsp;&nbsp;"pdt\_0No7umEyEyApMgJMBRwHI": \["git-version-control"\],

&nbsp;&nbsp;"pdt\_0No7umGHodyphlPy7kVuw": \["shell-mastery"\],

&nbsp;&nbsp;"pdt\_0No7umI46jJ6QFGzDz9Wn": \["data-forging"\],

&nbsp;&nbsp;"pdt\_0No7umIT3vq6wQTDTLitA": \["docker-containers"\],

&nbsp;&nbsp;"pdt\_0No7umIuzv3LovBDw9mJs": \["cicd-pipelines"\],

&nbsp;&nbsp;"pdt\_0No7umJqQBlWvxZErrHqv": \["terraform-iac"\],

&nbsp;&nbsp;"pdt\_0No7umKG7Jh3e57OeTvC6": \["kubernetes"\],

&nbsp;

&nbsp;&nbsp;// Tracks

&nbsp;&nbsp;"pdt\_0No7umL7kMaekaV8OezhO": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "shell-mastery", "data-forging"

&nbsp;&nbsp;\],

&nbsp;&nbsp;"pdt\_0No7umM8Suwb4dLat0K8G": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-version-control", "docker-containers",

&nbsp;&nbsp;&nbsp;&nbsp;"cicd-pipelines", "terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;

&nbsp;&nbsp;// Full catalog

&nbsp;&nbsp;"pdt\_0No7umMgQG48JrJhqRVkc": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-version-control", "shell-mastery",

&nbsp;&nbsp;&nbsp;&nbsp;"data-forging", "docker-containers", "cicd-pipelines",

&nbsp;&nbsp;&nbsp;&nbsp;"terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;

&nbsp;&nbsp;// Team seats — same entitlements as full catalog, seat count handled separately

&nbsp;&nbsp;"pdt\_0No7umNCBCxwKBAZALtnS": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-version-control", "shell-mastery",

&nbsp;&nbsp;&nbsp;&nbsp;"data-forging", "docker-containers", "cicd-pipelines",

&nbsp;&nbsp;&nbsp;&nbsp;"terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

&nbsp;&nbsp;"pdt\_0No7umOh6PEBDCQTfXWzm": \[

&nbsp;&nbsp;&nbsp;&nbsp;"linux-foundations", "git-version-control", "shell-mastery",

&nbsp;&nbsp;&nbsp;&nbsp;"data-forging", "docker-containers", "cicd-pipelines",

&nbsp;&nbsp;&nbsp;&nbsp;"terraform-iac", "kubernetes"

&nbsp;&nbsp;\],

};

&nbsp;

// CLI course slugs must match internal slugs in lib/lessons.sh exactly

// Verify against: grep "^COURSES" lib/lessons.sh

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 3 — Webhook Handler

&nbsp;

Implement the Dodo webhook endpoint in \`src/index.ts\`:

&nbsp;

\`\`\`typescript

// POST /webhooks/dodo

async function handleDodoWebhook(request: Request, env: Env): Promise\<Response\> {

&nbsp;

&nbsp;&nbsp;// 1\. Verify Dodo webhook signature

&nbsp;&nbsp;const signature \= request.headers.get("webhook-signature") ?? "";

&nbsp;&nbsp;const body \= await request.text();

&nbsp;&nbsp;const valid \= await verifyDodoSignature(body, signature, env.DODO\_WEBHOOK\_SECRET);

&nbsp;&nbsp;if (\!valid) return new Response("Unauthorized", { status: 401 });

&nbsp;

&nbsp;&nbsp;const event \= JSON.parse(body);

&nbsp;

&nbsp;&nbsp;// 2\. Only process successful payments

&nbsp;&nbsp;if (event.type \!== "payment.succeeded") {

&nbsp;&nbsp;&nbsp;&nbsp;return new Response("OK", { status: 200 });

&nbsp;&nbsp;}

&nbsp;

&nbsp;&nbsp;const { product\_id, customer\_email, order\_id } \= event.data;

&nbsp;

&nbsp;&nbsp;// 3\. Idempotency — skip if order already processed

&nbsp;&nbsp;const existing \= await env.ORDERS.get(order\_id);

&nbsp;&nbsp;if (existing) return new Response("OK", { status: 200 });

&nbsp;

&nbsp;&nbsp;// 4\. Look up entitlements

&nbsp;&nbsp;const entitlements \= PRODUCT\_ENTITLEMENTS\[product\_id\] ?? \[\];

&nbsp;&nbsp;if (entitlements.length \=== 0\) {

&nbsp;&nbsp;&nbsp;&nbsp;console.error(\`Unknown product\_id: ${product\_id}\`);

&nbsp;&nbsp;&nbsp;&nbsp;return new Response("OK", { status: 200 });

&nbsp;&nbsp;}

&nbsp;

&nbsp;&nbsp;// 5\. Generate license key

&nbsp;&nbsp;const licenseKey \= await generateLicenseKey(order\_id, env.HMAC\_SECRET);

&nbsp;

&nbsp;&nbsp;// 6\. Store in KV

&nbsp;&nbsp;const licenseRecord \= {

&nbsp;&nbsp;&nbsp;&nbsp;key: licenseKey,

&nbsp;&nbsp;&nbsp;&nbsp;email: customer\_email,

&nbsp;&nbsp;&nbsp;&nbsp;product\_id,

&nbsp;&nbsp;&nbsp;&nbsp;entitlements,

&nbsp;&nbsp;&nbsp;&nbsp;order\_id,

&nbsp;&nbsp;&nbsp;&nbsp;created\_at: new Date().toISOString(),

&nbsp;&nbsp;&nbsp;&nbsp;activated: false,

&nbsp;&nbsp;&nbsp;&nbsp;activated\_at: null,

&nbsp;&nbsp;&nbsp;&nbsp;seats: product\_id \=== "pdt\_0No7umNCBCxwKBAZALtnS" ? 5

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: product\_id \=== "pdt\_0No7umOh6PEBDCQTfXWzm" ? 10

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;: 1,

&nbsp;&nbsp;};

&nbsp;

&nbsp;&nbsp;await env.LICENSES.put(licenseKey, JSON.stringify(licenseRecord));

&nbsp;&nbsp;await env.ORDERS.put(order\_id, licenseKey); // idempotency index

&nbsp;

&nbsp;&nbsp;// 7\. Send license email via Resend

&nbsp;&nbsp;await sendLicenseEmail(customer\_email, licenseKey, entitlements, env.RESEND\_API\_KEY);

&nbsp;

&nbsp;&nbsp;return new Response("OK", { status: 200 });

}

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 4 — License Validation Endpoint

&nbsp;

\`\`\`typescript

// GET /license/validate?key=\<key\>

async function handleValidate(request: Request, env: Env): Promise\<Response\> {

&nbsp;&nbsp;const url \= new URL(request.url);

&nbsp;&nbsp;const key \= url.searchParams.get("key");

&nbsp;

&nbsp;&nbsp;if (\!key) return Response.json({ valid: false, error: "No key provided" }, { status: 400 });

&nbsp;

&nbsp;&nbsp;const record \= await env.LICENSES.get(key);

&nbsp;&nbsp;if (\!record) return Response.json({ valid: false, error: "License not found" }, { status: 404 });

&nbsp;

&nbsp;&nbsp;const license \= JSON.parse(record);

&nbsp;

&nbsp;&nbsp;// Mark activated on first validation

&nbsp;&nbsp;if (\!license.activated) {

&nbsp;&nbsp;&nbsp;&nbsp;license.activated \= true;

&nbsp;&nbsp;&nbsp;&nbsp;license.activated\_at \= new Date().toISOString();

&nbsp;&nbsp;&nbsp;&nbsp;await env.LICENSES.put(key, JSON.stringify(license));

&nbsp;&nbsp;}

&nbsp;

&nbsp;&nbsp;return Response.json({

&nbsp;&nbsp;&nbsp;&nbsp;valid: true,

&nbsp;&nbsp;&nbsp;&nbsp;email: license.email,

&nbsp;&nbsp;&nbsp;&nbsp;entitlements: license.entitlements,

&nbsp;&nbsp;&nbsp;&nbsp;product\_id: license.product\_id,

&nbsp;&nbsp;&nbsp;&nbsp;seats: license.seats,

&nbsp;&nbsp;&nbsp;&nbsp;activated\_at: license.activated\_at,

&nbsp;&nbsp;});

}

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 5 — License Key Generator \+ Email Sender

&nbsp;

\`\`\`typescript

async function generateLicenseKey(orderId: string, secret: string): Promise\<string\> {

&nbsp;&nbsp;const encoder \= new TextEncoder();

&nbsp;&nbsp;const keyMaterial \= await crypto.subtle.importKey(

&nbsp;&nbsp;&nbsp;&nbsp;"raw", encoder.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, \["sign"\]

&nbsp;&nbsp;);

&nbsp;&nbsp;const signature \= await crypto.subtle.sign("HMAC", keyMaterial, encoder.encode(orderId));

&nbsp;&nbsp;const hex \= Array.from(new Uint8Array(signature))

&nbsp;&nbsp;&nbsp;&nbsp;.map(b \=\> b.toString(16).padStart(2, "0")).join("");

&nbsp;&nbsp;// Format: PRAC-XXXX-XXXX-XXXX-XXXX

&nbsp;&nbsp;return \`PRAC\-$hex.slice(0,4)-${hex.slice(4,8)}\-$hex.slice(8,12)-${hex.slice(12,16)}\`.toUpperCase();

}

&nbsp;

async function sendLicenseEmail(

&nbsp;&nbsp;email: string,

&nbsp;&nbsp;key: string,

&nbsp;&nbsp;entitlements: string\[\],

&nbsp;&nbsp;resendKey: string

): Promise\<void\> {

&nbsp;&nbsp;const courseList \= entitlements.map(e \=\> \`  • ${e}\`).join("\\n");

&nbsp;&nbsp;await fetch("https://api.resend.com/emails", {

&nbsp;&nbsp;&nbsp;&nbsp;method: "POST",

&nbsp;&nbsp;&nbsp;&nbsp;headers: {

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Authorization": \`Bearer ${resendKey}\`,

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Content-Type": "application/json",

&nbsp;&nbsp;&nbsp;&nbsp;},

&nbsp;&nbsp;&nbsp;&nbsp;body: JSON.stringify({

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;from: "Practicum CLI \<practicum@mpingo.ai\>",

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;to: email,

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;subject: "Your Practicum CLI License Key",

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;text: \`Your Practicum CLI license key:\\n\\n${key}\\n\\nActivate with:\\n  practicum license activate ${key}\\n\\nCourses unlocked:\\n${courseList}\\n\\nPracticum CLI — Precision tools that last.\\nhttps://practicum-cli.dev\`,

&nbsp;&nbsp;&nbsp;&nbsp;}),

&nbsp;&nbsp;});

}

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 6 — Router and CORS

&nbsp;

Wire all endpoints with CORS headers for the CLI:

&nbsp;

\`\`\`typescript

export default {

&nbsp;&nbsp;async fetch(request: Request, env: Env): Promise\<Response\> {

&nbsp;&nbsp;&nbsp;&nbsp;const url \= new URL(request.url);

&nbsp;&nbsp;&nbsp;&nbsp;const method \= request.method;

&nbsp;

&nbsp;&nbsp;&nbsp;&nbsp;// CORS preflight

&nbsp;&nbsp;&nbsp;&nbsp;if (method \=== "OPTIONS") {

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return new Response(null, {

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;headers: {

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Access-Control-Allow-Origin": "\*",

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Access-Control-Allow-Methods": "GET, POST",

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"Access-Control-Allow-Headers": "Content-Type",

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;},

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;});

&nbsp;&nbsp;&nbsp;&nbsp;}

&nbsp;

&nbsp;&nbsp;&nbsp;&nbsp;if (method \=== "POST" && url.pathname \=== "/webhooks/dodo") {

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return handleDodoWebhook(request, env);

&nbsp;&nbsp;&nbsp;&nbsp;}

&nbsp;

&nbsp;&nbsp;&nbsp;&nbsp;if (method \=== "GET" && url.pathname \=== "/license/validate") {

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return handleValidate(request, env);

&nbsp;&nbsp;&nbsp;&nbsp;}

&nbsp;

&nbsp;&nbsp;&nbsp;&nbsp;if (method \=== "GET" && url.pathname \=== "/health") {

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return Response.json({ status: "ok", worker: "practicum-api" });

&nbsp;&nbsp;&nbsp;&nbsp;}

&nbsp;

&nbsp;&nbsp;&nbsp;&nbsp;return new Response("Not found", { status: 404 });

&nbsp;&nbsp;}

};

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 7 — Deploy API Worker \+ Custom Domain

&nbsp;

\`\`\`powershell

wrangler deploy \--cwd workers/practicum-api

\`\`\`

&nbsp;

Add custom domain \`api.practicum-cli.dev\` in Cloudflare dashboard:

Workers & Pages → practicum-api → Settings → Domains & Routes → Add Custom Domain → api.practicum-cli.dev

&nbsp;

Verify:

\`\`\`powershell

curl https://api.practicum-cli.dev/health

\# Expected: {"status":"ok","worker":"practicum-api"}

\`\`\`

&nbsp;

\---

&nbsp;

\#\# Task 8 — Update CLI License Handler (lib/license.sh)

&nbsp;

Replace local-only validation with server validation:

&nbsp;

\`\`\`bash

PRACTICUM\_API="https://api.practicum-cli.dev"

LICENSE\_FILE="$HOME/.practicum/license.json"

LICENSE\_CACHE\_TTL=86400  \# 24 hours in seconds

&nbsp;

practicum\_license\_activate() {

&nbsp;&nbsp;local key="$1"

&nbsp;&nbsp;if \[ \-z "$key" \]; then

&nbsp;&nbsp;&nbsp;&nbsp;echo "Usage: practicum license activate \<key\>"

&nbsp;&nbsp;&nbsp;&nbsp;return 1

&nbsp;&nbsp;fi

&nbsp;

&nbsp;&nbsp;echo "  Validating license..."

&nbsp;&nbsp;local response

&nbsp;&nbsp;response\=$(curl-sf"$PRACTICUM\_API/license/validate?key=$key")

&nbsp;&nbsp;local exit\_code=$?

&nbsp;

&nbsp;&nbsp;if \[ $exit\_code \-ne 0 \]; then

&nbsp;&nbsp;&nbsp;&nbsp;echo "  Could not reach license server. Check your connection."

&nbsp;&nbsp;&nbsp;&nbsp;return 1

&nbsp;&nbsp;fi

&nbsp;

&nbsp;&nbsp;local valid

&nbsp;&nbsp;valid\=$(echo"$response" | jq \-r '.valid')

&nbsp;

&nbsp;&nbsp;if \[ "$valid" \!= "true" \]; then

&nbsp;&nbsp;&nbsp;&nbsp;local error

&nbsp;&nbsp;&nbsp;&nbsp;error\=$(echo"$response" | jq \-r '.error')

&nbsp;&nbsp;&nbsp;&nbsp;echo "  License invalid: $error"

&nbsp;&nbsp;&nbsp;&nbsp;return 1

&nbsp;&nbsp;fi

&nbsp;

&nbsp;&nbsp;\# Write validated license locally with timestamp

&nbsp;&nbsp;echo "$response"|jq--argts"$(date \-u \+%Y-%m-%dT%H:%M:%SZ)" \\

&nbsp;&nbsp;&nbsp;&nbsp;'. \+ {cached\_at: $ts}' \> "$LICENSE\_FILE"

&nbsp;

&nbsp;&nbsp;local email

&nbsp;&nbsp;email\=$(echo"$response" | jq \-r '.email')

&nbsp;&nbsp;echo ""

&nbsp;&nbsp;echo "  ✓ License activated for $email"

&nbsp;&nbsp;echo "  Courses unlocked:"

&nbsp;&nbsp;echo "$response" | jq \-r '.entitlements\[\]' | while read \-r course; do

&nbsp;&nbsp;&nbsp;&nbsp;echo "    • $course"

&nbsp;&nbsp;done

&nbsp;&nbsp;echo ""

}

&nbsp;

can\_access\_course() {

&nbsp;&nbsp;local course\_slug="$1"

&nbsp;

&nbsp;&nbsp;\# CLI Immersion always free

&nbsp;&nbsp;\[ "$course\_slug" \= "00-cli-immersion" \] && return 0

&nbsp;

&nbsp;&nbsp;\# Check local cache first

&nbsp;&nbsp;if \[ \-f "$LICENSE\_FILE" \]; then

&nbsp;&nbsp;&nbsp;&nbsp;local cached\_at valid

&nbsp;&nbsp;&nbsp;&nbsp;cached\_at\=$(jq-r'.cache{d}_{a}t//empty'"$LICENSE\_FILE")

&nbsp;&nbsp;&nbsp;&nbsp;valid\=$(jq-r'.valid//false'"$LICENSE\_FILE")

&nbsp;

&nbsp;&nbsp;&nbsp;&nbsp;if \[ "$valid"="true"]&&[-n"$cached\_at" \]; then

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\# Check cache age

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;local cache\_epoch now\_epoch age

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;cache\_epoch\=$(date-d"$cached\_at" \+%s 2\>/dev/null || date \-j \-f "%Y-%m-%dT%H:%M:%SZ" "$cached\_at" \+%s 2\>/dev/null)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;now\_epoch=$(date \+%s)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;age=$(( now\_epoch \- cache\_epoch ))

&nbsp;

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;if \[ "$age"-lt"$LICENSE\_TTL" \]; then

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\# Check entitlements from cache

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;local entitled

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;entitled\=$(jq-r--argc"$course\_slug" '.entitlements\[\] | select(. \== $c)'"$LICENSE\_FILE")

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\[ \-n "$entitled" \] && return 0

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;fi

&nbsp;&nbsp;&nbsp;&nbsp;fi

&nbsp;&nbsp;fi

&nbsp;

&nbsp;&nbsp;\# Cache miss or expired — revalidate

&nbsp;&nbsp;local key

&nbsp;&nbsp;key\=$(jq-r'.key//empty'"$LICENSE\_FILE" 2\>/dev/null)

&nbsp;&nbsp;if \[ \-n "$key" \]; then

&nbsp;&nbsp;&nbsp;&nbsp;local response

&nbsp;&nbsp;&nbsp;&nbsp;response\=$(curl-sf"$PRACTICUM\_API/license/validate?key=$key" 2\>/dev/null)

&nbsp;&nbsp;&nbsp;&nbsp;if \[ $? \-eq 0 \]; then

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;echo "$response"|jq--argts"$(date \-u \+%Y-%m-%dT%H:%M:%SZ)" \\

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'. \+ {cached\_at: $ts}' \> "$LICENSE\_FILE"

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;local entitled

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;entitled\=$(echo"$response" | jq \-r \--arg c "$course\_slug" '.entitlements\[\] | select(. \== $c)')

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;\[ \-n "$entitled" \] && return 0

&nbsp;&nbsp;&nbsp;&nbsp;fi

&nbsp;&nbsp;fi

&nbsp;

&nbsp;&nbsp;return 1

}

\`\`\`

&nbsp;

Note: \`can\_access\_day\` must call \`can\_access\_course\` for the course-level

check in addition to the day number check. Wire accordingly without breaking

the existing day\_num \-le 3 free tier logic.

&nbsp;

\---

&nbsp;

\#\# Task 9 — Configure Dodo Webhook

&nbsp;

In Dodo Payments dashboard:

\- Webhook URL: \`https://api.practicum-cli.dev/webhooks/dodo\`

\- Events: \`payment.succeeded\`

\- Copy the webhook signing secret → \`wrangler secret put DODO\_WEBHOOK\_SECRET\`

&nbsp;

\---

&nbsp;

\#\# Definition of Done

\- \[ \] workers/practicum-api/ scaffolded with wrangler.toml, src/index.ts

\- \[ \] KV namespaces LICENSES and ORDERS created, IDs in wrangler.toml

\- \[ \] Secrets set: DODO\_WEBHOOK\_SECRET, HMAC\_SECRET, RESEND\_API\_KEY

\- \[ \] All 13 product IDs mapped to correct entitlements

\- \[ \] Webhook handler verifies Dodo signature before processing

\- \[ \] Idempotency: duplicate order\_id webhooks do not generate duplicate keys

\- \[ \] License key format: PRAC-XXXX-XXXX-XXXX-XXXX

\- \[ \] Resend email sends key \+ course list on successful payment

\- \[ \] GET /license/validate returns entitlements JSON

\- \[ \] GET /health returns 200

\- \[ \] wrangler deploy succeeds for practicum-api

\- \[ \] api.practicum-cli.dev custom domain resolves

\- \[ \] curl /health → {"status":"ok","worker":"practicum-api"}

\- \[ \] lib/license.sh activate command calls API, writes validated cache

\- \[ \] can\_access\_course checks entitlements from server response

\- \[ \] CLI Immersion exemption preserved (00-cli-immersion bypasses all checks)

\- \[ \] Offline grace: cached license valid for 24h without server call

\- \[ \] Dodo webhook configured to point at api.practicum-cli.dev

\- \[ \] Test end-to-end: simulate webhook POST → KV entry → validate GET → entitlements returned

\- \[ \] Audit items 1, 2, 3 marked RESOLVED in docs/gating-audit.md with commit hash

\- \[ \] git push origin main

&nbsp;