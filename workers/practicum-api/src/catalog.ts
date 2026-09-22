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
}

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
