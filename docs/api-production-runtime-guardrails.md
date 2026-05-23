# API Production Runtime Guardrails

`craftalism-deployment` owns the production runtime guardrails for `craftalism-api`: container memory limits, JVM process options, deployment-time validation, exposed runtime environment, and operator documentation. API market semantics remain owned by `craftalism-api`.

## JVM And Container Budget

The production API profile gives Spring Boot explicit JVM ceilings instead of relying on the previous tight implicit budget:

```text
-Xms48m -Xmx144m -Xss512k -XX:+UseSerialGC -XX:MaxMetaspaceSize=128m -XX:ReservedCodeCacheSize=48m -XX:+ExitOnOutOfMemoryError
```

The small-host profile pairs that with `API_MEM_LIMIT=576m` and `API_MEM_RESERVATION=384m`. The `standard` profile raises the API JVM and container budget for less constrained hosts.

The small-host values come from the `craftalism-api:1.1.2` runtime diagnostics on the `friend-paper` variant: heap stayed healthy below the `144m` max, metaspace used roughly `86-89MiB`, code cache committed roughly `16-17MiB`, and the process had about 25 threads. The old `96m` metaspace cap was fragile; `128m` is the measured steady-state cap to keep. Native Memory Tracking is diagnostic-only and should not stay in steady-state `JAVA_TOOL_OPTIONS`.

`./prod` validates that the configured JVM budget fits inside `API_MEM_LIMIT` before startup or config rendering. The validation accounts for:

- max heap from `-Xmx` or `-XX:MaxRAMPercentage`
- `-XX:MaxMetaspaceSize`
- `-XX:ReservedCodeCacheSize`
- `-Xss` multiplied by `API_JVM_THREAD_BUDGET`
- required native/container headroom

If validation fails, lower the heap, metaspace, code cache, or thread budget, or raise `API_MEM_LIMIT`. Do not only raise JVM ceilings without preserving container headroom.

## SpringDoc Production Default

Production disables API docs by default:

```text
API_SPRINGDOC_API_DOCS_ENABLED=false
API_SPRINGDOC_SWAGGER_UI_ENABLED=false
```

This reduces unnecessary production runtime surface. Local development overrides intentionally enable SpringDoc/Swagger UI by default through `docker-compose.local.yml`; operators can still enable these variables explicitly in a controlled environment when needed.

## Market Request Pressure

The API owns rate-limit behavior and rejection semantics. Deployment owns the runtime defaults that prevent unlimited-by-omission market request pressure:

```text
MARKET_QUOTE_RATE_LIMIT_MAX_REQUESTS=120
MARKET_EXECUTE_RATE_LIMIT_MAX_REQUESTS=30
MARKET_RATE_LIMIT_WINDOW_SECONDS=60
```

Set a max requests value to `0` only when intentionally disabling that API limiter. `MARKET_RATE_LIMIT_WINDOW_SECONDS` must remain positive. Tune these values in `.env` based on player count, plugin debounce settings, and observed API load.
