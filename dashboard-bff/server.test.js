const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  matchApprovedAuthenticatedReadRoute,
  matchApprovedAuthenticatedWriteRoute,
  matchApprovedWriteRoute,
} = require("./server.js");

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

test("allows only approved dashboard market category write routes", () => {
  assert.equal(
    matchApprovedWriteRoute("POST", "/api/dashboard/market/categories"),
    "/api/dashboard/market/categories",
  );
  assert.equal(
    matchApprovedWriteRoute(
      "PATCH",
      "/api/dashboard/market/categories/farming",
    ),
    "/api/dashboard/market/categories/farming",
  );
  assert.equal(
    matchApprovedWriteRoute(
      "DELETE",
      "/api/dashboard/market/categories/farming",
    ),
    "/api/dashboard/market/categories/farming",
  );
});

test("allows market events admin read route with market admin scope", () => {
  assert.deepEqual(
    matchApprovedAuthenticatedReadRoute("GET", "/api/dashboard/market/events"),
    {
      targetPath: "/api/dashboard/market/events",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedAuthenticatedReadRoute("GET", "/api/dashboard/market/events/"),
    {
      targetPath: "/api/dashboard/market/events",
      scope: "market:admin",
    },
  );
});

test("allows market events admin mutation routes with market admin scope", () => {
  assert.deepEqual(
    matchApprovedAuthenticatedWriteRoute(
      "POST",
      "/api/dashboard/market/events",
    ),
    {
      targetPath: "/api/dashboard/market/events",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedAuthenticatedWriteRoute(
      "PATCH",
      "/api/dashboard/market/events/summer-sale",
    ),
    {
      targetPath: "/api/dashboard/market/events/summer-sale",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedAuthenticatedWriteRoute(
      "POST",
      "/api/dashboard/market/events/summer-sale/cancel",
    ),
    {
      targetPath: "/api/dashboard/market/events/summer-sale/cancel",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedAuthenticatedWriteRoute(
      "POST",
      "/api/dashboard/market/events/supersede",
    ),
    {
      targetPath: "/api/dashboard/market/events/supersede",
      scope: "market:admin",
    },
  );
});

test("rejects direct API writes and unapproved dashboard paths", () => {
  assert.equal(matchApprovedWriteRoute("POST", "/api/players"), null);
  assert.equal(matchApprovedWriteRoute("PATCH", "/api/balances/example"), null);
  assert.equal(matchApprovedWriteRoute("POST", "/api/dashboard/transactions"), null);
  assert.equal(matchApprovedWriteRoute("PUT", "/api/dashboard/market/items/dirt"), null);
  assert.equal(matchApprovedWriteRoute("GET", "/api/dashboard/players"), null);
  assert.equal(
    matchApprovedAuthenticatedReadRoute("GET", "/api/dashboard/players"),
    null,
  );
  assert.equal(
    matchApprovedAuthenticatedReadRoute("POST", "/api/dashboard/market/events"),
    null,
  );
  assert.equal(
    matchApprovedAuthenticatedWriteRoute(
      "DELETE",
      "/api/dashboard/market/events/summer-sale",
    ),
    null,
  );
});
