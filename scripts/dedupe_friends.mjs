#!/usr/bin/env node
//
// One-time cleanup for the `friends` collection.
//
// Older builds wrote friendship docs with a random id and an unnormalized
// friendPhone, so the same person could end up with several documents. This
// rewrites every friendship to the canonical `{userPhone}_{friendPhone}` id
// with normalized phone fields and deletes the leftovers.
//
// Usage:
//   node scripts/dedupe_friends.mjs            # dry run
//   node scripts/dedupe_friends.mjs --apply
//
// Auth: uses `gcloud auth print-access-token` (project owner bypasses rules).

import { execSync } from "node:child_process";

const PROJECT = "northpole-c5d92";
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const APPLY = process.argv.includes("--apply");

const token = execSync("gcloud auth print-access-token").toString().trim();
const authHeaders = { Authorization: `Bearer ${token}` };

/** Canonical digits-only phone, mirrors PhoneNumber.normalize in the app. */
function normalize(phone) {
  const digits = (phone ?? "").replace(/\D/g, "");
  return digits.length === 10 ? `1${digits}` : digits;
}

async function fetchAllFriends() {
  const docs = [];
  let pageToken;
  do {
    const url = new URL(`${BASE}/friends`);
    url.searchParams.set("pageSize", "300");
    if (pageToken) url.searchParams.set("pageToken", pageToken);
    const res = await fetch(url, { headers: authHeaders });
    if (!res.ok) throw new Error(`list failed: ${res.status} ${await res.text()}`);
    const json = await res.json();
    docs.push(...(json.documents ?? []));
    pageToken = json.nextPageToken;
  } while (pageToken);
  return docs;
}

function readDoc(doc) {
  const f = doc.fields ?? {};
  return {
    id: doc.name.split("/").pop(),
    name: doc.name,
    userPhone: normalize(f.userPhone?.stringValue),
    friendPhone: normalize(f.friendPhone?.stringValue),
    friendName: f.friendName?.stringValue ?? "",
    addedAt: f.addedAt?.timestampValue ?? doc.createTime,
    hiddenChildren: (f.hiddenChildren?.arrayValue?.values ?? [])
      .map((v) => v.stringValue)
      .filter(Boolean),
  };
}

async function writeDoc(id, data) {
  const res = await fetch(`${BASE}/friends/${encodeURIComponent(id)}`, {
    method: "PATCH",
    headers: { ...authHeaders, "Content-Type": "application/json" },
    body: JSON.stringify({
      fields: {
        userPhone: { stringValue: data.userPhone },
        friendPhone: { stringValue: data.friendPhone },
        friendName: { stringValue: data.friendName },
        addedAt: { timestampValue: data.addedAt },
        hiddenChildren: {
          arrayValue: { values: data.hiddenChildren.map((c) => ({ stringValue: c })) },
        },
      },
    }),
  });
  if (!res.ok) throw new Error(`write ${id} failed: ${res.status} ${await res.text()}`);
}

async function deleteDoc(id) {
  const res = await fetch(`${BASE}/friends/${encodeURIComponent(id)}`, {
    method: "DELETE",
    headers: authHeaders,
  });
  if (!res.ok) throw new Error(`delete ${id} failed: ${res.status} ${await res.text()}`);
}

const raw = await fetchAllFriends();
const groups = new Map();

for (const doc of raw) {
  const entry = readDoc(doc);
  if (!entry.userPhone || !entry.friendPhone) {
    console.log(`skipping ${entry.id}: missing phone`);
    continue;
  }
  const key = `${entry.userPhone}_${entry.friendPhone}`;
  if (!groups.has(key)) groups.set(key, []);
  groups.get(key).push(entry);
}

let rewrites = 0;
let deletions = 0;

for (const [targetId, entries] of [...groups].sort()) {
  entries.sort((a, b) => new Date(a.addedAt) - new Date(b.addedAt));
  const newest = entries[entries.length - 1];
  const canonical = entries.find((e) => e.id === targetId);

  const merged = {
    userPhone: newest.userPhone,
    friendPhone: newest.friendPhone,
    friendName: (canonical ?? newest).friendName || newest.friendName,
    addedAt: entries[0].addedAt,
    hiddenChildren: [...new Set(entries.flatMap((e) => e.hiddenChildren))],
  };

  const stale = entries.filter((e) => e.id !== targetId);
  const alreadyClean = stale.length === 0 && canonical !== undefined;
  if (alreadyClean) continue;

  console.log(
    `${targetId}  "${merged.friendName}"  rewrite${stale.length ? `, delete ${stale.length} legacy doc(s): ${stale.map((s) => s.id).join(", ")}` : ""}`
  );

  if (APPLY) {
    await writeDoc(targetId, merged);
    for (const doc of stale) await deleteDoc(doc.id);
  }
  rewrites += 1;
  deletions += stale.length;
}

console.log(
  `\n${APPLY ? "Applied" : "Dry run"}: ${raw.length} docs -> ${groups.size} friendships; ${rewrites} rewritten, ${deletions} legacy docs deleted.`
);
if (!APPLY) console.log("Re-run with --apply to write changes.");
