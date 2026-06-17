#!/usr/bin/env node
/**
 * Generate LiveKit tokens for 2 test users.
 *
 * Usage:
 *   node scripts/gen_tokens.mjs [room-name]
 *
 * Reads credentials from .env (or .env.local) in the repo root:
 *   LIVEKIT_URL=wss://your-project.livekit.cloud
 *   LIVEKIT_API_KEY=your_api_key
 *   LIVEKIT_API_SECRET=your_api_secret
 */

import { readFileSync, existsSync } from 'fs';
import { createHmac } from 'crypto';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dir = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dir, '..');

// ──── Load .env ───────────────────────────────────────────────────────────────

function loadEnv() {
  for (const name of ['.env.local', '.env']) {
    const path = join(repoRoot, name);
    if (!existsSync(path)) continue;
    const lines = readFileSync(path, 'utf8').split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eq = trimmed.indexOf('=');
      if (eq === -1) continue;
      const key = trimmed.slice(0, eq).trim();
      const val = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, '');
      if (!(key in process.env)) process.env[key] = val;
    }
    console.error(`Loaded ${name}`);
    break;
  }
}

loadEnv();

const LIVEKIT_URL        = process.env.LIVEKIT_URL;
const LIVEKIT_API_KEY    = process.env.LIVEKIT_API_KEY;
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET;

if (!LIVEKIT_URL || !LIVEKIT_API_KEY || !LIVEKIT_API_SECRET) {
  console.error(
    'Missing env vars. Create .env with:\n' +
    '  LIVEKIT_URL=wss://your-project.livekit.cloud\n' +
    '  LIVEKIT_API_KEY=your_api_key\n' +
    '  LIVEKIT_API_SECRET=your_api_secret'
  );
  process.exit(1);
}

// ──── Minimal JWT (HS256) — no external deps ──────────────────────────────────

function b64url(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function signJwt(payload, secret) {
  const header  = b64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body    = b64url(JSON.stringify(payload));
  const sig     = b64url(
    createHmac('sha256', secret).update(`${header}.${body}`).digest()
  );
  return `${header}.${body}.${sig}`;
}

// ──── LiveKit token payload ───────────────────────────────────────────────────

function makeToken(identity, name, room) {
  const now = Math.floor(Date.now() / 1000);
  return signJwt(
    {
      iss: LIVEKIT_API_KEY,
      sub: identity,
      nbf: now,
      exp: now + 3600,               // 1 hour
      name,
      video: {
        room,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
      },
    },
    LIVEKIT_API_SECRET
  );
}

// ──── Main ────────────────────────────────────────────────────────────────────

const room = process.argv[2] || 'test-room';

const users = [
  { identity: 'user1', name: 'User 1' },
  { identity: 'user2', name: 'User 2' },
];

const results = users.map(u => ({
  ...u,
  token: makeToken(u.identity, u.name, room),
}));

// Machine-readable JSON to stdout
console.log(JSON.stringify({ url: LIVEKIT_URL, room, users: results }, null, 2));

// Human-readable summary to stderr
console.error('\n─────────────────────────────────────────────────────');
console.error(`Room   : ${room}`);
console.error(`Server : ${LIVEKIT_URL}`);
console.error('─────────────────────────────────────────────────────');
for (const u of results) {
  console.error(`\n[${u.name}]`);
  console.error(`  identity : ${u.identity}`);
  console.error(`  token    : ${u.token.slice(0, 40)}…`);
}
console.error('\nPaste URL + token into the example app Connect page.');
console.error('─────────────────────────────────────────────────────\n');
