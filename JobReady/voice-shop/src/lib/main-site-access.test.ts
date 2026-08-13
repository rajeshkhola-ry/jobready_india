import assert from "node:assert/strict";
import test from "node:test";

import {
  getMainSiteAccessMessage,
  shouldOpenMainSiteForGuestAccess,
} from "./main-site-access";

test("guest access routes users to the main GETREADYJOB homepage", () => {
  assert.equal(shouldOpenMainSiteForGuestAccess(false), true);
  assert.equal(shouldOpenMainSiteForGuestAccess(true), false);
  assert.match(
    getMainSiteAccessMessage(),
    /main homepage \(getreadyjob\.com\)/i,
  );
});
