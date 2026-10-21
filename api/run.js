// POST /api/run -> ask Colab to run the tests again (needs the deploy key)

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
    status.state = "requested";
    status.requestedAt = new Date().toISOString();
    await save("status", status);
    return send(res, 200, { ok: true });
  } catch (err) {
    return send(res, 500, { error: err.message });
  }
}
