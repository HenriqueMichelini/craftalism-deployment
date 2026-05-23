# Craftalism Minecraft VPS Memory/GC Test Handoff

Environment:
- VPS: 2 GB RAM
- Minecraft: Paper 1.21.4 build 232, Java 21
- Workload tested: aggressive creative sprint-flying to stress chunk loading/generation
- Goal: keep non-Minecraft services low-memory and prioritize Minecraft responsiveness

Non-Minecraft services were successfully reduced:
- API dropped from ~286 MiB to ~80–110 MiB idle
- Auth server dropped from ~135 MiB to ~50–70 MiB idle
- Dashboard/BFF/Postgres are low footprint
- This part is considered successful

Minecraft tests:

1. Serial/default GC, 768M heap-ish
- JVM: `-Xmx768M -Xms512M`
- GC observed: `Copy`, `MarkSweepCompact`
- Metrics:
  - MSPT median: ~2.83ms
  - MSPT 95%ile: ~9.83ms
  - MSPT max: ~6800ms
  - Full GC: `MarkSweepCompact`, ~2260ms average during test
- Interpretation:
  - Best steady tick performance
  - Bad rare freezes due old/full GC
  - Not ideal for production if full-GC stalls happen during gameplay

2. Full Aikar flags, 896M heap
- JVM: G1GC + Aikar flags + `-Xmx896M -Xms896M`
- Metrics:
  - MSPT median: ~4.97ms
  - MSPT 95%ile: ~39.3ms
  - MSPT max: ~1500ms
  - G1 Old GC: 0
- Interpretation:
  - Removed catastrophic full GC
  - Too much steady CPU/memory pressure for this VPS
  - Felt worse during chunk stress
  - Do not keep this profile

3. Minimal G1, 896M heap
- JVM: `-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC -Xmx896M -Xms896M`
- Metrics:
  - MSPT median: ~4.67ms
  - MSPT 95%ile: ~31.1ms
  - MSPT max: ~689ms
  - G1 Old GC: 0
- Interpretation:
  - Better than Aikar
  - Still high host memory pressure
  - 896M heap does not appear necessary

4. Minimal G1, 768M heap
- JVM: `-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC -Xmx768M -Xms768M`
- Metrics:
  - MSPT median: ~5.29ms
  - MSPT 95%ile: ~40.3ms
  - MSPT max: ~1100ms
  - G1 Old GC: 0
  - Heap used: ~481.5M / 768M
- Interpretation:
  - Best current compromise
  - Avoids full-GC stalls
  - Uses less memory than 896M
  - Remaining lag is probably chunk loading/generation + CPU pressure, not GC

Recommended current profile:
```env
USE_AIKAR_FLAGS=false
MINECRAFT_INIT_MEMORY=768M
MINECRAFT_MEMORY=768M
MINECRAFT_MEM_LIMIT=1280m
MINECRAFT_MEM_RESERVATION=768m
MINECRAFT_JVM_XX_OPTS=-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC
```

Conclusion:
- GC was a real issue in the first test because Serial GC caused multi-second MarkSweepCompact pauses.
- Full Aikar is too heavy for this 2 GB VPS.
- Minimal G1 with 768M heap is the best tested compromise.
- The remaining lag during creative sprint-flying is likely not primarily GC anymore. It is mostly chunk generation/loading, CPU pressure, and tight host memory.

Next recommended tests:

1. Keep minimal G1 768M.
2. Lower Minecraft load:
     - `MINECRAFT_VIEW_DISTANCE=5`
     - `MINECRAFT_SIMULATION_DISTANCE=3`
3. Pre-generate chunks around the playable area.
4. Retest normal gameplay separately from creative sprint-flying, because creative sprint-flying into new chunks is an extreme stress test.

Test results:
```text
first_test.sparkprofile
Serial GC / default-style run
JVM: -Xmx768M -Xms512M
GC: Copy + MarkSweepCompact
Result: best median/95% MSPT, but catastrophic full-GC stalls.

second_test.sparkprofile
Aikar flags enabled
JVM: G1GC + full Aikar flags + -Xmx896M -Xms896M
Result: removed old/full GC, but felt worse due higher CPU/memory pressure.

third_test.sparkprofile
Minimal G1, 896M heap
JVM: -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC -Xmx896M -Xms896M
Result: better than Aikar, but still too heavy for the VPS.

fourth_test.sparkprofile
Minimal G1, 768M heap
JVM: -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+DisableExplicitGC -Xmx768M -Xms768M
Result: best compromise so far.
```
