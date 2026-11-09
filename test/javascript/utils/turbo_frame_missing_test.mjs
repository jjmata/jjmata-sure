import assert from "node:assert/strict";
import test from "node:test";

import { handleTurboFrameMissing } from "../../../app/javascript/utils/turbo_frame_missing.mjs";

function buildEvent(response) {
  const event = {
    defaultPrevented: false,
    visited: null,
    target: { id: "drawer" },
    detail: {
      response,
      visit: (visitedResponse) => {
        event.visited = visitedResponse;
      },
    },
    preventDefault() {
      this.defaultPrevented = true;
    },
  };
  return event;
}

test("shows an error instead of throwing when the response failed", () => {
  const event = buildEvent({ ok: false, status: 502, redirected: false });
  const notified = [];

  handleTurboFrameMissing(event, { notifyError: (details) => notified.push(details) });

  assert.equal(event.defaultPrevented, true);
  assert.deepEqual(notified, [{ frame_id: "drawer", status: 502 }]);
  assert.equal(event.visited, null);
});

test("shows an error when a redirect ends on a failed response", () => {
  const event = buildEvent({ ok: false, status: 520, redirected: true });
  const notified = [];

  handleTurboFrameMissing(event, { notifyError: (details) => notified.push(details) });

  assert.equal(event.defaultPrevented, true);
  assert.equal(notified.length, 1);
  assert.equal(event.visited, null);
});

test("visits the redirect target as a full page", () => {
  const response = { ok: true, status: 200, redirected: true };
  const event = buildEvent(response);
  const notified = [];

  handleTurboFrameMissing(event, { notifyError: (details) => notified.push(details) });

  assert.equal(event.defaultPrevented, true);
  assert.equal(event.visited, response);
  assert.equal(notified.length, 0);
});

test("keeps the Turbo default for a successful response without the frame", () => {
  const event = buildEvent({ ok: true, status: 200, redirected: false });
  const notified = [];

  handleTurboFrameMissing(event, { notifyError: (details) => notified.push(details) });

  assert.equal(event.defaultPrevented, false);
  assert.equal(event.visited, null);
  assert.equal(notified.length, 0);
});
