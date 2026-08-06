/**
 * Permanent Firestore rules deploy helper for skillforge-ai-4f2da.
 *
 * Why this exists:
 * firebase-tools may report HTTP 409 on /releases when the REAL failure is
 * PATCH 400 INVALID_ARGUMENT (often ruleset too large / too complex).
 * Keep firestore.rules under the deployable size (~190-195KB source after
 * helper flattening). If deploy fails with 400, shrink nested helpers /
 * remove comments before retrying — do NOT delete the cloud.firestore release.
 *
 * Usage:
 *   node scripts/deploy-firestore-rules.js
 * or:
 *   firebase deploy --only firestore:rules --project skillforge-ai-4f2da
 */
"use strict";

const { spawnSync } = require("child_process");
const fs = require("fs");
const path = require("path");

const ROOT = path.join(__dirname, "..");
const RULES = path.join(ROOT, "firestore.rules");
const PROJECT = "skillforge-ai-4f2da";
const SOFT_LIMIT = 195000;

function main() {
  let src = fs.readFileSync(RULES, "utf8");
  const normalized = src.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  if (normalized !== src) {
    fs.writeFileSync(RULES, normalized, "utf8");
    src = normalized;
    console.log("[deploy] normalized CRLF -> LF");
  }
  const bytes = Buffer.byteLength(src);
  console.log(`[deploy] firestore.rules bytes=${bytes} (soft limit ~${SOFT_LIMIT})`);
  if (bytes > SOFT_LIMIT) {
    console.warn(
      "[deploy] WARNING: rules file is large; release may fail with PATCH 400 " +
        "(CLI may misreport as 409). Prefer helper flattening / comment trim."
    );
  }

  const r = spawnSync(
    "firebase",
    ["deploy", "--only", "firestore:rules", "--project", PROJECT, "--non-interactive"],
    { cwd: ROOT, stdio: "inherit", shell: true }
  );
  if (r.status !== 0) {
    console.error(
      "\n[deploy] FAILED. If you see HTTP 409, re-run with --debug and look for " +
        "PATCH .../releases/cloud.firestore returning 400 INVALID_ARGUMENT — " +
        "that usually means the ruleset exceeds Firebase size/complexity limits."
    );
    process.exit(r.status || 1);
  }
  console.log("[deploy] OK");
}

main();
