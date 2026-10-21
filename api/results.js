// GET  /api/results  -> the latest results (anyone can view)
// POST /api/results  -> save new results (needs the deploy key)

import { load, save, keyIsRight, send, EMPTY_STATUS } from "../lib/store.js";

export default async function handler(req, res) {
  try {
    if (req.method === "GET") {
      const results = await load("results", null);
      if (results === null) {
        return send(res, 404, { error: "No results yet" });
      }
      return send(res, 200, results);
    }

    if (req.method === "POST") {
      if (!keyIsRight(req)) {
        return send(res, 401, { error: "Wrong deploy key" });
      }
      const results = req.body;
      if (!results || !results.runs || !results.runs.healthy || !results.runs.fault) {
        return send(res, 400, { error: "Results must include a healthy run and a fault run" });
      }
      await save("results", results);

      const status = await load("status", EMPTY_STATUS);
      status.state = "idle";
      status.lastRunAt = new Date().toISOString();
      status.lastSeen = status.lastRunAt;
      await save("status", status);

      return send(res, 200, { ok: true });
    }

    return send(res, 405, { error: "Use GET or POST" });
  } catch (err) {
    return send(res, 500, { error: err.message });
  }
}
