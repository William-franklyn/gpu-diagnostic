// Small helpers for saving and loading data in Upstash Redis,
// plus the password check used by every "write" request.

const DB_URL = process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL;
const DB_TOKEN = process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN;

export const EMPTY_STATUS = {
  state: "idle",        // idle = waiting for a run, requested, running
  lastSeen: null,       // last time Colab checked in
  requestedAt: null,    // last time someone clicked Run again
  lastRunAt: null,      // last time results arrived
  runCount: 0           // how many runs have been received
};

async function redis(command) {
  if (!DB_URL || !DB_TOKEN) {
    throw new Error("Storage isn't connected. In Vercel, add Upstash for Redis under Storage, then redeploy.");
  }
  const response = await fetch(DB_URL, {
    method: "POST",
    headers: { Authorization: "Bearer " + DB_TOKEN },
    body: JSON.stringify(command)
  });
  const data = await response.json();
  if (data.error) {
    throw new Error("Storage error: " + data.error);
  }
  return data.result;
}

export async function load(key, fallback) {
  const value = await redis(["GET", key]);
  if (value === null || value === undefined) {
    return fallback;
  }
  return JSON.parse(value);
}

export async function save(key, value) {
  await redis(["SET", key, JSON.stringify(value)]);
}

export function keyIsRight(req) {
  const expected = process.env.DEPLOY_KEY;
  if (!expected) {
    return false;
  }
  return req.headers["x-deploy-key"] === expected;
}

export function send(res, code, body) {
  res.setHeader("Cache-Control", "no-store");
  res.status(code).json(body);
}
