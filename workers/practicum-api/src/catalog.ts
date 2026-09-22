// Shape of a licence record in the LICENSES KV namespace, shared by the Dodo
// webhook (index.ts) and classroom seat provisioning (roster.ts). Both write
// the same shape so lib/license.sh needs no knowledge of where a key came from.

export const FULL_CATALOG = [
  "linux-foundations", "git-essentials", "shell-mastery", "data-forging",
  "docker-essentials", "cicd-pipelines", "terraform-iac", "kubernetes",
];

export type LicenseRole = "learner" | "instructor-admin";

export interface LicenseRecord {
  key: string;
  email: string;
  product_id: string;
  entitlements: string[];
  order_id: string;
  seats: number;
  role: LicenseRole;
  created_at: string;
  expires_at: string;
  activated: boolean;
  activated_at: string | null;
  revoked: boolean;
  revoked_at: string | null;
  revoked_reason: string | null;
  // Present only on classroom-issued keys. Solo licences never carry these,
  // and nothing in the validate path requires them.
  classroom_id?: string;
  member_id?: string;
  // Synthetic licences minted for smoke tests. Any customer count, revenue
  // report or export MUST filter these out — see countableLicense().
  is_test?: boolean;
}

// The single place a licence record is constructed. The Dodo webhook, classroom
// seat provisioning and the smoke-key minter all go through here so a record
// can never be hand-assembled and drift from what /license/validate expects.
export function buildLicenseRecord(opts: {
  key: string;
  email: string;
  product_id: string;
  entitlements: string[];
  order_id: string;
  seats?: number;
  role?: LicenseRole;
  expires_at: string;
  classroom_id?: string;
  member_id?: string;
  is_test?: boolean;
}): LicenseRecord {
  return {
    key: opts.key,
    email: opts.email,
    product_id: opts.product_id,
    entitlements: opts.entitlements,
    order_id: opts.order_id,
    seats: opts.seats ?? 1,
    role: opts.role ?? "learner",
    created_at: new Date().toISOString(),
    expires_at: opts.expires_at,
    activated: false,
    activated_at: null,
    revoked: false,
    revoked_at: null,
    revoked_reason: null,
    ...(opts.classroom_id ? { classroom_id: opts.classroom_id, member_id: opts.member_id } : {}),
    ...(opts.is_test ? { is_test: true } : {}),
  };
}

// Whether a licence represents a real customer. Every count, revenue figure or
// export of licences must be filtered through this, not written ad hoc.
export const countableLicense = (r: Pick<LicenseRecord, "is_test">) => r.is_test !== true;

const enc = new TextEncoder();

export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", enc.encode(value));
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// PRAC-XXXX-XXXX-XXXX-XXXX from the first 16 hex chars of an HMAC.
export async function licenseKeyFrom(message: string, secret: string): Promise<string> {
  const k = await crypto.subtle.importKey("raw", enc.encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign("HMAC", k, enc.encode(message));
  const hex = Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .toUpperCase();
  return `PRAC-${hex.slice(0, 4)}-${hex.slice(4, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}`;
}
