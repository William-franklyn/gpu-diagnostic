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
      // Stamp the results with the exact time and a run number,
      // so every run is easy to tell apart even if the results are identical
      const status = await load("status", EMPTY_STATUS);
      const now = new Date().toISOString();
      status.runCount = (status.runCount || 0) + 1;
      results.receivedAt = now;
      results.runNumber = status.runCount;
      await save("results", results);

      status.state = "idle";
      status.lastRunAt = now;
      status.lastSeen = now;
      await save("status", status);

      return send(res, 200, { ok: true });
    }

    return send(res, 405, { error: "Use GET or POST" });
  } catch (err) {
    return send(res, 500, { error: err.message });
  }
}
