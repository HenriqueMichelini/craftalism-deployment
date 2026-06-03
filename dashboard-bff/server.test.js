const assert = require("node:assert/strict");
const { test } = require("node:test");

const {
  matchApprovedApiWriteRoute,
  matchApprovedScopedReadRoute,
  matchApprovedScopedWriteRoute,
} = require("./server.js");

test("allows only approved dashboard player api write routes", () => {
  assert.equal(
    matchApprovedApiWriteRoute("POST", "/api/dashboard/players"),
    "/api/players",
  );
  assert.equal(
    matchApprovedApiWriteRoute(
      "PATCH",
      "/api/dashboard/players/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
    ),
    "/api/players/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
  );
  assert.equal(
    matchApprovedApiWriteRoute(
      "DELETE",
      "/api/dashboard/players/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
    ),
    "/api/players/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
  );
});

test("allows only approved dashboard balance api write routes", () => {
  assert.equal(
    matchApprovedApiWriteRoute("POST", "/api/dashboard/balances"),
    "/api/balances",
  );
  assert.equal(
    matchApprovedApiWriteRoute(
      "PATCH",
      "/api/dashboard/balances/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
    ),
    "/api/balances/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
  );
  assert.equal(
    matchApprovedApiWriteRoute(
      "DELETE",
      "/api/dashboard/balances/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
    ),
    "/api/balances/018f6b86-7a4b-7c1f-9a7c-2d7850425f21",
  );
});

test("allows only approved dashboard market item api write routes", () => {
  assert.equal(
    matchApprovedApiWriteRoute("POST", "/api/dashboard/market/items"),
    "/api/dashboard/market/items",
  );
  assert.equal(
    matchApprovedApiWriteRoute("PATCH", "/api/dashboard/market/items/dirt"),
    "/api/dashboard/market/items/dirt",
  );
  assert.equal(
    matchApprovedApiWriteRoute("DELETE", "/api/dashboard/market/items/dirt"),
    "/api/dashboard/market/items/dirt",
  );
});

test("allows only approved dashboard market category api write routes", () => {
  assert.equal(
    matchApprovedApiWriteRoute("POST", "/api/dashboard/market/categories"),
    "/api/dashboard/market/categories",
  );
  assert.equal(
    matchApprovedApiWriteRoute(
      "PATCH",
      "/api/dashboard/market/categories/farming",
    ),
    "/api/dashboard/market/categories/farming",
  );
  assert.equal(
    matchApprovedApiWriteRoute(
      "DELETE",
      "/api/dashboard/market/categories/farming",
    ),
    "/api/dashboard/market/categories/farming",
  );
});

test("allows market events admin read route with market admin scope", () => {
  assert.deepEqual(
    matchApprovedScopedReadRoute("GET", "/api/dashboard/market/events"),
    {
      targetPath: "/api/dashboard/market/events",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedScopedReadRoute("GET", "/api/dashboard/market/events/"),
    {
      targetPath: "/api/dashboard/market/events",
      scope: "market:admin",
    },
  );
});

test("allows market event template admin read route with market admin scope", () => {
  assert.deepEqual(
    matchApprovedScopedReadRoute(
      "GET",
      "/api/dashboard/market/event-templates",
    ),
    {
      targetPath: "/api/dashboard/market/event-templates",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedScopedReadRoute(
      "GET",
      "/api/dashboard/market/event-templates/",
    ),
    {
      targetPath: "/api/dashboard/market/event-templates",
      scope: "market:admin",
    },
  );
});

test("allows market events admin mutation routes with market admin scope", () => {
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "POST",
      "/api/dashboard/market/events",
    ),
    {
      targetPath: "/api/dashboard/market/events",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "PATCH",
      "/api/dashboard/market/events/summer-sale",
    ),
    {
      targetPath: "/api/dashboard/market/events/summer-sale",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "POST",
      "/api/dashboard/market/events/summer-sale/cancel",
    ),
    {
      targetPath: "/api/dashboard/market/events/summer-sale/cancel",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "POST",
      "/api/dashboard/market/events/supersede",
    ),
    {
      targetPath: "/api/dashboard/market/events/supersede",
      scope: "market:admin",
    },
  );
});

test("allows market event template admin create route with market admin scope", () => {
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "POST",
      "/api/dashboard/market/event-templates",
    ),
    {
      targetPath: "/api/dashboard/market/event-templates",
      scope: "market:admin",
    },
  );
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "POST",
      "/api/dashboard/market/event-templates/",
    ),
    {
      targetPath: "/api/dashboard/market/event-templates",
      scope: "market:admin",
    },
  );
});

test("allows market event template admin delete route with market admin scope", () => {
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "DELETE",
      "/api/dashboard/market/event-templates/example",
    ),
    {
      targetPath: "/api/dashboard/market/event-templates/example",
      scope: "market:admin",
    },
  );
});

test("allows market drift reset with market admin scope", () => {
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "POST",
      "/api/dashboard/market/drift/reset",
    ),
    {
      targetPath: "/api/dashboard/market/drift/reset",
      scope: "market:admin",
    },
  );
});

test("rejects direct API writes and unapproved dashboard paths", () => {
  assert.equal(matchApprovedApiWriteRoute("POST", "/api/players"), null);
  assert.equal(
    matchApprovedApiWriteRoute("PATCH", "/api/balances/example"),
    null,
  );
  assert.equal(
    matchApprovedApiWriteRoute("POST", "/api/dashboard/transactions"),
    null,
  );
  assert.equal(
    matchApprovedApiWriteRoute("PUT", "/api/dashboard/market/items/dirt"),
    null,
  );
  assert.equal(matchApprovedApiWriteRoute("GET", "/api/dashboard/players"), null);
  assert.equal(
    matchApprovedApiWriteRoute(
      "DELETE",
      "/api/dashboard/market/event-templates/example",
    ),
    null,
  );
  assert.equal(
    matchApprovedScopedReadRoute("GET", "/api/dashboard/players"),
    null,
  );
  assert.equal(
    matchApprovedScopedReadRoute("POST", "/api/dashboard/market/events"),
    null,
  );
  assert.equal(
    matchApprovedScopedWriteRoute(
      "DELETE",
      "/api/dashboard/market/events/summer-sale",
    ),
    null,
  );
  assert.equal(
    matchApprovedScopedWriteRoute(
      "PATCH",
      "/api/dashboard/market/event-templates/example",
    ),
    null,
  );
  assert.equal(
    matchApprovedScopedWriteRoute(
      "POST",
      "/api/dashboard/market/event-templates/example",
    ),
    null,
  );
});

test("allows market event template admin update route with market admin scope", () => {
  assert.deepEqual(
    matchApprovedScopedWriteRoute(
      "PUT",
      "/api/dashboard/market/event-templates/ship_wreck_farming_goods",
    ),
    {
      targetPath:
        "/api/dashboard/market/event-templates/ship_wreck_farming_goods",
      scope: "market:admin",
    },
  );
});
