#!/usr/bin/env node
/**
 * C2 migration (2026-07-03): move the four compensation fields
 * (salaryAmount / salaryType / paymentMethod / paymentNumber) OFF the
 * branch-readable users/{uid} docs into users/{uid}/private/compensation.
 *
 * Runs with PRIVILEGED owner credentials (rules-bypassing, IAM-authorized)
 * via the Firestore REST API — the machine has no Application Default
 * Credentials, and firebase-admin's Firestore client requires ADC/cert, so
 * tokens are minted from the signed-in gcloud CLI user instead. Same
 * privilege level as the Admin SDK; same safety model:
 *
 *   1. DRY RUN is the default — prints what would migrate, writes nothing.
 *   2. --apply first writes a timestamped BACKUP JSON (gitignored) of every
 *      value it is about to move, THEN per user: write subdoc → read back
 *      and verify → only then delete the legacy fields. A failed verify
 *      skips the delete for that user (nothing is ever lost).
 *   3. --rollback <backup.json> restores the legacy top-level fields from a
 *      backup (subdocs are left in place — harmless duplicates).
 *   4. A final verification pass re-reads everything and reports drift.
 *
 *   node tool/migrate_compensation.js                 # dry run
 *   node tool/migrate_compensation.js --apply
 *   node tool/migrate_compensation.js --rollback compensation_backup_<ts>.json
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const PROJECT_ID = "bazic-d9ad7";
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const FIELDS = ["salaryAmount", "salaryType", "paymentMethod", "paymentNumber"];

const args = process.argv.slice(2);
const APPLY = args.includes("--apply");
const rollbackIdx = args.indexOf("--rollback");
const ROLLBACK_FILE = rollbackIdx >= 0 ? args[rollbackIdx + 1] : null;

const token = execSync("gcloud auth print-access-token").toString().trim();
const HEADERS = {
  "Authorization": `Bearer ${token}`,
  "Content-Type": "application/json",
  "x-goog-user-project": PROJECT_ID,
};

async function api(method, url, body) {
  const res = await fetch(url, {
    method,
    headers: HEADERS,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`${method} ${url} → ${res.status}: ${await res.text()}`);
  }
  return res.json();
}

// ── Firestore REST value (en/de)coding for our field types ──
function decode(v) {
  if (v === undefined) return undefined;
  if ("stringValue" in v) return v.stringValue;
  if ("integerValue" in v) return Number(v.integerValue);
  if ("doubleValue" in v) return v.doubleValue;
  if ("nullValue" in v) return null;
  return undefined;
}
function encode(v) {
  if (typeof v === "string") return { stringValue: v };
  if (typeof v === "number") {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  throw new Error(`Unsupported value: ${v}`);
}

function pickCompensation(docFields) {
  const out = {};
  for (const f of FIELDS) {
    const v = decode((docFields || {})[f]);
    if (v !== undefined && v !== null) out[f] = v;
  }
  return out;
}

/** PATCH with an updateMask = Firestore merge; masked-but-absent = delete. */
function patchUrl(docPath, maskFields) {
  const mask = maskFields
    .map((f) => `updateMask.fieldPaths=${encodeURIComponent(f)}`)
    .join("&");
  return `${BASE}/${docPath}?${mask}`;
}

async function listAllUsers() {
  const docs = [];
  let pageToken = "";
  do {
    const url = `${BASE}/users?pageSize=300${pageToken ? `&pageToken=${pageToken}` : ""}`;
    const page = await api("GET", url);
    for (const d of page.documents || []) docs.push(d);
    pageToken = page.nextPageToken || "";
  } while (pageToken);
  return docs;
}

const uidOf = (doc) => doc.name.split("/").pop();

async function rollback(file) {
  const backup = JSON.parse(fs.readFileSync(file, "utf8"));
  console.log(`Rolling back ${backup.users.length} user(s) from ${file}…`);
  for (const u of backup.users) {
    const fields = {};
    for (const [k, v] of Object.entries(u.fields)) fields[k] = encode(v);
    await api("PATCH", patchUrl(`users/${u.uid}`, Object.keys(u.fields)), { fields });
    console.log(`  restored ${u.uid}: ${Object.keys(u.fields).join(", ")}`);
  }
  console.log("Rollback complete (subdocuments left in place).");
}

async function main() {
  if (ROLLBACK_FILE) return rollback(ROLLBACK_FILE);

  const docs = await listAllUsers();
  const migrants = [];
  for (const doc of docs) {
    const comp = pickCompensation(doc.fields);
    if (Object.keys(comp).length > 0) migrants.push({ uid: uidOf(doc), fields: comp });
  }

  console.log(`Scanned ${docs.length} user doc(s); ${migrants.length} carry legacy compensation fields.`);
  for (const m of migrants) {
    console.log(`  ${m.uid}: ${Object.keys(m.fields).join(", ")}`);
  }
  if (migrants.length === 0) {
    console.log("Nothing to migrate.");
    return;
  }
  if (!APPLY) {
    console.log("\nDRY RUN — nothing written. Re-run with --apply to migrate.");
    return;
  }

  // ── Backup BEFORE any write ──
  const backupFile = path.join(
    __dirname, "..", `compensation_backup_${Date.now()}.json`);
  fs.writeFileSync(backupFile, JSON.stringify({
    project: PROJECT_ID,
    at: new Date().toISOString(),
    users: migrants,
  }, null, 2));
  console.log(`\nBackup written: ${backupFile}`);

  // ── Migrate: write subdoc → verify readback → delete legacy fields ──
  let migrated = 0;
  for (const m of migrants) {
    const subPath = `users/${m.uid}/private/compensation`;
    const fields = { migratedAt: { timestampValue: new Date().toISOString() } };
    for (const [k, v] of Object.entries(m.fields)) fields[k] = encode(v);
    await api("PATCH",
      patchUrl(subPath, [...Object.keys(m.fields), "migratedAt"]), { fields });

    const check = await api("GET", `${BASE}/${subPath}`);
    const ok = Object.entries(m.fields)
      .every(([k, v]) => decode((check.fields || {})[k]) === v);
    if (!ok) {
      console.error(`  ✗ ${m.uid}: subdoc readback mismatch — legacy fields KEPT`);
      continue;
    }
    // Mask the legacy fields, send them absent → field delete.
    await api("PATCH", patchUrl(`users/${m.uid}`, Object.keys(m.fields)),
      { fields: {} });
    migrated++;
    console.log(`  ✓ ${m.uid}: moved ${Object.keys(m.fields).join(", ")}`);
  }

  // ── Final verification pass ──
  let residue = 0;
  for (const doc of await listAllUsers()) {
    const leftover = pickCompensation(doc.fields);
    if (Object.keys(leftover).length > 0) {
      residue++;
      console.error(`  ! ${uidOf(doc)} still carries: ${Object.keys(leftover).join(", ")}`);
    }
  }
  console.log(`\nMigrated ${migrated}/${migrants.length}; ${residue} doc(s) with residue.`);
  console.log(residue === 0 && migrated === migrants.length
    ? "VERIFIED: no compensation data remains on public user docs."
    : "ATTENTION: review the lines above before proceeding.");
}

main().then(() => process.exit(0)).catch((e) => {
  console.error("Migration failed:", e);
  process.exit(1);
});
