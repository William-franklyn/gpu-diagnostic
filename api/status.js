// GET /api/status -> what's happening right now (anyone can view)

import { load, send, EMPTY_STATUS } from "../lib/store.js";

export default async function handler(req, res) {
  try {
    if (req.method !== "GET") {
      return send(res, 405, { error: "Use GET" });
    }
    const status = await load("status", EMPTY_STATUS);
    status.now = new Date().toISOString();   // so the page can tell how long ago Colab checked in
    return send(res, 200, status);
  } catch (err) {
    return send(res, 500, { error: err.message });
  }
}
