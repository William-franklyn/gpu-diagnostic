// POST /api/poll -> Colab checks in every few seconds (needs the deploy key).
// Answers { run: true } when someone has clicked Run again.

import { load, save, keyIsRight, send, EMPTY_STATUS } from "../lib/store.js";

export default async function handler(req, res) {
  try {
    if (req.method !== "POST") {
      return send(res, 405, { error: "Use POST" });
    }
    if (!keyIsRight(req)) {
      return send(res, 401, { error: "Wrong deploy key" });
    }
    const status = await load("status", EMPTY_STATUS);
    status.lastSeen = new Date().toISOString();

    let run = false;
    if (status.state === "requested") {
      status.state = "running";
      run = true;
    }
    await save("status", status);
    return send(res, 200, { run: run });
  } catch (err) {
    return send(res, 500, { error: err.message });
  }
}
