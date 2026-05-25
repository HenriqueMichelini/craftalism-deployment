const assert = require("node:assert/strict");
const { test } = require("node:test");

const { matchApprovedWriteRoute } = require("./server.js");

test("allows only approved dashboard player write routes", () => {
  assert.equal(
    matchApprovedWriteRoute("POST", "/api/dashboard/players"),
    "/api/players",
  );
  assert.equal(
    matchApprovedWriteRoute(
      "PATCH",
      "/api/dashboard/players/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
    ),
    "/api/players/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
  );
  assert.equal(
    matchApprovedWriteRoute(
      "DELETE",
      "/api/dashboard/players/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
    ),
    "/api/players/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
  );
});

test("allows only approved dashboard balance write routes", () => {
  assert.equal(
    matchApprovedWriteRoute("POST", "/api/dashboard/balances"),
    "/api/balances",
  );
  assert.equal(
    matchApprovedWriteRoute(
      "PATCH",
      "/api/dashboard/balances/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
    ),
    "/api/balances/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
  );
  assert.equal(
    matchApprovedWriteRoute(
      "DELETE",
      "/api/dashboard/balances/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
    ),
    "/api/balances/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
  );
});

test("allows only approved dashboard market item write routes", () => {
  assert.equal(
    matchApprovedWriteRoute("POST", "/api/dashboard/market/items"),
    "/api/dashboard/market/items",
  );
  assert.equal(
    matchApprovedWriteRoute("PATCH", "/api/dashboard/market/items/dirt"),
    "/api/dashboard/market/items/dirt",
  );
  assert.equal(
    matchApprovedWriteRoute("DELETE", "/api/dashboard/market/items/dirt"),
    "/api/dashboard/market/items/dirt",
  );
});

test("rejects direct API writes and unapproved dashboard paths", () => {
  assert.equal(matchApprovedWriteRoute("POST", "/api/players"), null);
  assert.equal(matchApprovedWriteRoute("PATCH", "/api/balances/example"), null);
  assert.equal(matchApprovedWriteRoute("POST", "/api/dashboard/transactions"), null);
  assert.equal(matchApprovedWriteRoute("PUT", "/api/dashboard/market/items/dirt"), null);
  assert.equal(matchApprovedWriteRoute("GET", "/api/dashboard/players"), null);
});
