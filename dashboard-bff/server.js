const http = require("node:http");

const port = Number(process.env.PORT || 8080);
const apiUpstreamUrl = trimTrailingSlash(
  process.env.API_UPSTREAM_URL || "http://api:8080",
);
const tokenUrl =
  process.env.DASHBOARD_BFF_TOKEN_URL ||
  process.env.AUTH_TOKEN_PATH ||
  "http://auth-server:9000/oauth2/token";
const clientId = process.env.DASHBOARD_BFF_CLIENT_ID || "dashboard-bff";
const clientSecret = process.env.DASHBOARD_BFF_CLIENT_SECRET;

const approvedApiWriteRoutes = [
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/players\/?$/,
    target: "/api/players",
  },
  {
    method: "PATCH",
    pattern: /^\/api\/dashboard\/players\/([^/]+)\/?$/,
    target: (match) => `/api/players/${match[1]}`,
  },
  {
    method: "DELETE",
    pattern: /^\/api\/dashboard\/players\/([^/]+)\/?$/,
    target: (match) => `/api/players/${match[1]}`,
  },
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/balances\/?$/,
    target: "/api/balances",
  },
  {
    method: "PATCH",
    pattern: /^\/api\/dashboard\/balances\/([^/]+)\/?$/,
    target: (match) => `/api/balances/${match[1]}`,
  },
  {
    method: "DELETE",
    pattern: /^\/api\/dashboard\/balances\/([^/]+)\/?$/,
    target: (match) => `/api/balances/${match[1]}`,
  },
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/market\/items\/?$/,
    target: "/api/dashboard/market/items",
  },
  {
    method: "PATCH",
    pattern: /^\/api\/dashboard\/market\/items\/([^/]+)\/?$/,
    target: (match) => `/api/dashboard/market/items/${match[1]}`,
  },
  {
    method: "DELETE",
    pattern: /^\/api\/dashboard\/market\/items\/([^/]+)\/?$/,
    target: (match) => `/api/dashboard/market/items/${match[1]}`,
  },
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/market\/categories\/?$/,
    target: "/api/dashboard/market/categories",
  },
  {
    method: "PATCH",
    pattern: /^\/api\/dashboard\/market\/categories\/([^/]+)\/?$/,
    target: (match) => `/api/dashboard/market/categories/${match[1]}`,
  },
  {
    method: "DELETE",
    pattern: /^\/api\/dashboard\/market\/categories\/([^/]+)\/?$/,
    target: (match) => `/api/dashboard/market/categories/${match[1]}`,
  },
];

const approvedScopedReadRoutes = [
  {
    method: "GET",
    pattern: /^\/api\/dashboard\/market\/events\/?$/,
    target: "/api/dashboard/market/events",
    scope: "market:admin",
  },
  {
    method: "GET",
    pattern: /^\/api\/dashboard\/market\/event-templates\/?$/,
    target: "/api/dashboard/market/event-templates",
    scope: "market:admin",
  },
];

const approvedScopedWriteRoutes = [
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/market\/drift\/reset\/?$/,
    target: "/api/dashboard/market/drift/reset",
    scope: "market:admin",
  },
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/market\/events\/?$/,
    target: "/api/dashboard/market/events",
    scope: "market:admin",
  },
  {
    method: "PATCH",
    pattern: /^\/api\/dashboard\/market\/events\/([^/]+)\/?$/,
    target: (match) => `/api/dashboard/market/events/${match[1]}`,
    scope: "market:admin",
  },
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/market\/events\/([^/]+)\/cancel\/?$/,
    target: (match) => `/api/dashboard/market/events/${match[1]}/cancel`,
    scope: "market:admin",
  },
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/market\/events\/supersede\/?$/,
    target: "/api/dashboard/market/events/supersede",
    scope: "market:admin",
  },
  {
    method: "POST",
    pattern: /^\/api\/dashboard\/market\/event-templates\/?$/,
    target: "/api/dashboard/market/event-templates",
    scope: "market:admin",
  },
  {
    method: "PUT",
    pattern: /^\/api\/dashboard\/market\/event-templates\/([^/]+)\/?$/,
    target: (match) => `/api/dashboard/market/event-templates/${match[1]}`,
    scope: "market:admin",
  },
  {
    method: "DELETE",
    pattern: /^\/api\/dashboard\/market\/event-templates\/([^/]+)\/?$/,
    target: (match) => `/api/dashboard/market/event-templates/${match[1]}`,
    scope: "market:admin",
  },
];

const cachedTokensByScope = new Map();

if (require.main === module) {
  const server = http.createServer(async (request, response) => {
    try {
      await handleRequest(request, response);
    } catch (error) {
      console.error("dashboard-bff request failed", error);
      sendText(response, 502, "Bad Gateway");
    }
  });

  server.listen(port, () => {
    console.log(`dashboard-bff listening on ${port}`);
  });
}

async function handleRequest(request, response) {
  const requestUrl = new URL(request.url || "/", `http://${request.headers.host}`);

  if (request.method === "GET" && requestUrl.pathname === "/health") {
    sendText(response, 200, "ok");
    return;
  }

  const approvedScopedWriteRoute = matchApprovedScopedWriteRoute(
    request.method,
    requestUrl.pathname,
  );

  if (approvedScopedWriteRoute) {
    const token = await getAccessToken(approvedScopedWriteRoute.scope);
    await proxyRequest(
      request,
      response,
      `${approvedScopedWriteRoute.targetPath}${requestUrl.search}`,
      {
        authorization: `Bearer ${token}`,
      },
    );
    return;
  }

  const approvedApiWriteRoute = matchApprovedApiWriteRoute(
    request.method,
    requestUrl.pathname,
  );

  if (approvedApiWriteRoute) {
    const token = await getAccessToken("api:write");
    await proxyRequest(request, response, approvedApiWriteRoute, {
      authorization: `Bearer ${token}`,
    });
    return;
  }

  const approvedScopedReadRoute = matchApprovedScopedReadRoute(
    request.method,
    requestUrl.pathname,
  );

  if (approvedScopedReadRoute) {
    const token = await getAccessToken(approvedScopedReadRoute.scope);
    await proxyRequest(
      request,
      response,
      `${approvedScopedReadRoute.targetPath}${requestUrl.search}`,
      {
        authorization: `Bearer ${token}`,
      },
    );
    return;
  }

  if (requestUrl.pathname.startsWith("/api/")) {
    if (!["GET", "HEAD", "OPTIONS"].includes(request.method || "")) {
      sendText(response, 403, "Forbidden");
      return;
    }

    await proxyRequest(request, response, `${requestUrl.pathname}${requestUrl.search}`);
    return;
  }

  sendText(response, 404, "Not Found");
}

function matchApprovedApiWriteRoute(method, pathname) {
  for (const route of approvedApiWriteRoutes) {
    if (route.method !== method) {
      continue;
    }

    const match = pathname.match(route.pattern);

    if (!match) {
      continue;
    }

    const targetPath =
      typeof route.target === "function" ? route.target(match) : route.target;

    return targetPath;
  }

  return null;
}

function matchApprovedScopedWriteRoute(method, pathname) {
  return matchApprovedScopedRoute(
    approvedScopedWriteRoutes,
    method,
    pathname,
  );
}

function matchApprovedScopedReadRoute(method, pathname) {
  return matchApprovedScopedRoute(
    approvedScopedReadRoutes,
    method,
    pathname,
  );
}

function matchApprovedScopedRoute(routes, method, pathname) {
  for (const route of routes) {
    if (route.method !== method) {
      continue;
    }

    const match = pathname.match(route.pattern);

    if (!match) {
      continue;
    }

    const targetPath =
      typeof route.target === "function" ? route.target(match) : route.target;

    return {
      targetPath,
      scope: route.scope,
    };
  }

  return null;
}

async function proxyRequest(request, response, targetPath, headers = {}) {
  const body = await readRequestBody(request);
  const upstreamResponse = await fetch(`${apiUpstreamUrl}${targetPath}`, {
    method: request.method,
    headers: buildForwardHeaders(request, headers),
    body: hasRequestBody(request.method) ? body : undefined,
    redirect: "manual",
  });

  response.writeHead(
    upstreamResponse.status,
    upstreamResponse.statusText,
    sanitizeResponseHeaders(upstreamResponse.headers),
  );

  const responseBody = Buffer.from(await upstreamResponse.arrayBuffer());
  response.end(responseBody);
}

async function getAccessToken(scope) {
  const cachedToken = cachedTokensByScope.get(scope);

  if (cachedToken && cachedToken.expiresAt > Date.now() + 30_000) {
    return cachedToken.accessToken;
  }

  if (!clientSecret) {
    throw new Error("DASHBOARD_BFF_CLIENT_SECRET is required");
  }

  const tokenResponse = await fetch(tokenUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "client_credentials",
      client_id: clientId,
      client_secret: clientSecret,
      scope,
    }),
  });

  if (!tokenResponse.ok) {
    throw new Error(`Token request failed with status ${tokenResponse.status}`);
  }

  const tokenPayload = await tokenResponse.json();
  const expiresInSeconds = Number(tokenPayload.expires_in || 300);

  cachedTokensByScope.set(scope, {
    accessToken: tokenPayload.access_token,
    expiresAt: Date.now() + expiresInSeconds * 1000,
  });

  return tokenPayload.access_token;
}

function buildForwardHeaders(request, extraHeaders) {
  const headers = {
    "Content-Type": request.headers["content-type"] || "application/json",
    Accept: request.headers.accept || "application/json",
    "X-Forwarded-Host": request.headers.host || "",
    "X-Forwarded-Proto": request.headers["x-forwarded-proto"] || "http",
    ...extraHeaders,
  };

  return Object.fromEntries(
    Object.entries(headers).filter(([, value]) => Boolean(value)),
  );
}

function sanitizeResponseHeaders(headers) {
  const sanitized = {};

  headers.forEach((value, key) => {
    if (["connection", "keep-alive", "transfer-encoding"].includes(key)) {
      return;
    }

    sanitized[key] = value;
  });

  return sanitized;
}

function readRequestBody(request) {
  return new Promise((resolve, reject) => {
    const chunks = [];

    request.on("data", (chunk) => chunks.push(chunk));
    request.on("end", () => resolve(Buffer.concat(chunks)));
    request.on("error", reject);
  });
}

function hasRequestBody(method) {
  return !["GET", "HEAD"].includes(method || "");
}

function trimTrailingSlash(value) {
  return value.replace(/\/$/, "");
}

function sendText(response, status, message) {
  response.writeHead(status, { "Content-Type": "text/plain; charset=utf-8" });
  response.end(message);
}

module.exports = {
  matchApprovedApiWriteRoute,
  matchApprovedScopedReadRoute,
  matchApprovedScopedWriteRoute,
};
