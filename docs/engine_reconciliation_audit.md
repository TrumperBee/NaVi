# Engine Reconciliation Audit

Date: 2026-10-02
Scope: diagnostic audit only — **no code changed** by this audit.
Reference: `docs/TRANSPORT_DATA_SPEC.md` (canonical; §1 fares, §2 journey FSM).

> **Phase 1 — completed (2026-10-02):** `lib/features/matatu/engines/` deleted (all 5 files). Re-check before deletion confirmed zero live references — the 5 classes appeared only in their own files and in `test/widget_test.dart` (imports + the `FareEstimationEngine`/`RouteMatchingEngine` groups), which were removed. `lib/features/matatu/` contained no other subfolders/files. `flutter analyze` 0 errors (232 baseline unchanged); test suite still passes with the 2 dead-engine test groups gone. The dormant-folder comparison below is preserved as historical record; the live journey engine analysis in Parts A/E and Phase 2 findings are now the relevant content.

> **Phase 2 — completed (2026-10-02):** all 6 defects repaired test-first (one red→green cycle each; detail in Part F). A notable correction to this audit's Finding 2/5: the boarding engine's `didBoard`/`didAlight` signals were not merely dead-file constants, they were **unreachable** — `_detectBoarding` required `previousState == walking && currentState == inVehicle && _vehicleCount >= 3`, but `_vehicleCount` reaches 3 only after 3 in-vehicle ticks when `previousState` is no longer walking (empirically probed across 5 speed profiles: never fires). Repairing the reachability gap is what resolved BOTH Finding 2 (alight fallback) AND Finding 5 (State-1 stall, closed as a byproduct — its red test passed on the first run). Test suite grew 179 → 186 (+7 new engine/provider tests: 3 for #1, 1 each for #2, #3, #4-5, #6). `flutter analyze` 0 errors, 229 issues (−2: removed two unused Firebase-constructing fields `_predictor`/`_reportService` from `JourneyProvider` that blocked provider-level tests).

Two parallel "engine" folders exist:

| Folder | Files | Lines | Wiring |
|---|---|---|---|
| `lib/features/journey/engines/` | 7 | ~800 | LIVE (see Part B) |
| `lib/features/matatu/engines/` | 5 | ~260 | DORMANT (see Part B) |

---

## Part A — Inventory

### Journey engines (live)

| File | Size | Responsibility |
|---|---|---|
| `boarding_detection_engine.dart` | 3.9 KB | Movement-state machine (stationary / walking / running / inVehicle) from a 20-sample speed history; emits `didBoard` (walking→inVehicle, 3 ticks) and `didAlight` (inVehicle→walking, 2 ticks), confidence 0..1. |
| `stage_geofence_engine.dart` | 3.1 KB | Stateful stage geofences via `StageDatabase.findNearbyStages`: radii approach 200 m / entry 50 m / exit 100 m; emits entered/approaching/exited events. |
| `route_matcher_engine.dart` | 5.1 KB | GPS path matcher: scores candidate `RouteRecord`s by per-point proximity (<500 m), bearing alignment, coverage; emits `RouteMatchResult` (current/next stage, stop index, `isOnRoute`, deviation). |
| `stop_progress_engine.dart` | 4.4 KB | Stop-rung position along a named stop list (cached via `StageDatabase.searchStages`); advances only forward; emits completed/total, current/next/previous stage, `stageChanged`. |
| `alight_detection_engine.dart` | 3.2 KB | Approach/alight detection vs a destination point: approach (<500 m & speed >1.0 m/s), alight (<100 m & speed <0.5 m/s & 10-sample speed-drop ratio <0.3), confidence from distance + speed drop. |
| `route_deviation_engine.dart` | 3.7 KB | Wrong-DIRECTION (bearing ±135…225°, 30-point path) and off-ROUTE (>500 m from expected path) detection; emits `DeviationResult` with `needsRerouting`. |
| `journey_auto_detector.dart` | 6.5 KB | **Orchestrator**. Subscribes `LiveLocationService` and fans each GPS sample to all six engines; runs an 8-value `JourneyPhase` FSM; fires callbacks (`onBoardingDetected`, `onStopReached`, `onApproachingDestination`, `onAlighted`, `onDeviation`). |

### Matatu engines (dormant)

| File | Size | Responsibility |
|---|---|---|
| `journey_tracking_engine.dart` | 2.1 KB | Trip odometer: 1 s `Timer`, haversine delta-distance accumulation, `stopTracking()` returns `{distance, duration, formatted_*}`. |
| `alight_notification_engine.dart` | 1.7 KB | Distance-only proximity latch to an alight point: `isApproaching < 300 m`, `hasNotified < 100 m` (`CheckResult`). |
| `stage_detection_engine.dart` | 1.9 KB | Stateless nearest-stage (`maxDistance 500 m`) / stages-in-radius (1000 m) / by-corridor lookups over **`SeedData`**. |
| `route_matching_engine.dart` | 1.4 KB | Static route catalog over **`SeedData`**: route-number set-intersection between stages, by-corridor/sacco/destination searches. |
| `fare_estimation_engine.dart` | 1.5 KB | Fare formula: `base 50 + 10/km`, peak ×1.2, night ×1.3, corridor/sacco multipliers. |

---

## Part B — Wiring audit (live vs dormant)

**Method:** for every file in both folders, every import / instantiation / member access was traced across `lib/`. 

### Journey engines: LIVE (one spine)

- `JourneyProvider` is created in the provider tree — `lib/main.dart:70` (`providers: [ ... ChangeNotifierProvider(create: (_) { final provider = JourneyProvider(); ... })`, wrapped at main.dart:61).
- `JourneyProvider` constructs the detector — `lib/providers/journey_provider.dart:19` (`final JourneyAutoDetector _autoDetector`).
- Detection starts when a journey starts with auto-advance on:
  - `journey_provider.dart:196` (`await _startAutoDetection()` inside `startJourney`)
  - `journey_provider.dart:148` (`toggleAutoAdvance` restart)
  - `_startAutoDetection` (journey_provider.dart:430-449) assigns the 5 callbacks and calls `_autoDetector.startDetection(destinationLat: … destinationLng: … startLat: -1.2833 startLng: 36.8167 routeStopNames: …)`.
- Orchestrator is the single GPS consumer for the features: `journey_auto_detector.dart:14` (`LiveLocationService`), `:77` (`_location.startTracking()`), `:78` (`_location.onLocation(_processSample)`). `startDetection` (auto_detector:60-79) primes all sub-engines: `_stopProgress.setRouteStops`, `_alight.setDestination`, `_deviation.setJourneyBounds`.
- `_processSample` (auto_detector:81-95) runs the whole engine set every sample: `_geofence.checkGeofences` (line 86, result **discarded/unawaited**), `_boarding.analyze` (88), `_routeMatcher.recordPoint` (89), `_deviation.recordUserPoint` (90), then `_detectPhaseTransitions` (93).
- Detector state is rendered on the live map: `lib/features/map/live_map_layer.dart:34` (`final JourneyAutoDetector detector`; reads `currentSpeed`, `routeConfidence`, `movementState`, `lastDeviation`, `isActive`).
- Consumer surface: `journey_screen.dart`, `home_screen.dart`, `main_map_screen.dart` (startJourney paths), `map_journey_overlay.dart`.

### Matatu engines: DORMANT (dead prototype era)

- **Zero references to any of the five files anywhere in `lib/`.** Only hits in the whole repo:
  - `test/widget_test.dart:6-7` imports `fare_estimation_engine.dart` + `route_matching_engine.dart`; groups at `widget_test.dart:101` (`FareEstimationEngine`) and `:117` (`RouteMatchingEngine`). No other file imports anything from `features/matatu/`.
- `features/matatu/` contains **only** the engines folder (no models, no services, no screens).
- The three remaining matatu files (`journey_tracking_engine`, `alight_notification_engine`, `stage_detection_engine`) have **no references anywhere, including tests**.

**Race verdict — there is NO race between the two folders.** The matatu folder is orphaned prototype code; the journey folder is the only wired engine system.

**Adjacent (not engine-folder) GPS consumer:** `NavigationProvider` runs its own position stream (`navigation_provider.dart:134` `startLiveTracking(distanceFilter: 5)`) and independently drives `_checkProgress` → `_updateRouteProgress` + instruction advance + arrival<50 m (lines 151-182). This is a second live GPS listener during a journey, but it is a polyline/turn tracker, distinct from the engine FSM. Flagged for awareness; it does not duplicate the FSM.

---

## Part C — Direct overlap comparison (the apparent "duplicates")

### Pair 1: `boarding_detection_engine` (journey) vs `journey_tracking_engine` (matatu)

- journey: movement/boarding state machine — `_detectBoarding()` fires only on `previousState == walking && currentState == inVehicle && _vehicleCount >= 3` (boarding_detection_engine.dart:95-105); thresholds 1.67/3.33/0.5 m/s (lines 29-31).
- matatu: pure odometer — `startTracking` starts `Timer.periodic(1s)` and `updatePosition` only accumulates `_distanceTraveled` (journey_tracking_engine.dart:33-54).

**Verdict: NOT a duplicate.** Same name-space, different jobs: one detects *boarding events*, the other is *trip telemetry*. The telemetry need is already covered live by `ActiveJourney` totals (`totalDistanceMeters` / `estimatedDuration`) and `JourneyProvider._startTimers`. Delete the matatu engine directly.

### Pair 2: `alight_detection_engine` (journey) vs `alight_notification_engine` (matatu)

- journey: approach = `distance < 500 && speed > 1.0`, alight = `distance < 100 && speed < 0.5 && speedDrop < 0.3` over a 10-sample speed window; single-shot latches `_approachingTriggered`/`_alightTriggered`; emits confidence (alight_detection_engine.dart:63-108).
- matatu: `_isApproaching = distance < 300; _hasNotified = distance < 100;` with no speed input, no window, no confidence (alight_notification_engine.dart:38-39); plus a `formattedDistance` convenience.

**Verdict: TRUE overlap — a simpler variant of the same problem (approach/alight proximity).** The journey engine is richer (speed-drop, confidence) *and live*; the matatu engine is threshold-only and dead. Only thing potentially worth porting is the extra 300 m "approaching" tier — the journey engine has 500/100 only. Recommend deleting matatu and (optionally) adding a 300 m intermediate tier later.

### Pair 3: `route_matcher_engine` (journey) vs `route_matching_engine` (matatu)

- journey: geometric matcher — score = proximity ×0.5 + direction ×0.3 + coverage ×0.2 against `RouteRecord.orderedStages` resolved via `StageDatabase` (route_matcher_engine.dart:83-111); returns current/next stage, stop index, `isOnRoute` (score > 0.3).
- matatu: **no geometry at all** — `findRoutesBetweenStages` = route-number set intersection of `StageModel.routes` over `SeedData.getRoutes()` (route_matching_engine.dart:5-21); plus seed catalog searches.

**Verdict: same intent, different quality classes.** The matatu "matcher" cannot verify you are on a route (`SeedData` is pre-GTFS; `RouteDatabase`/`StageRegistry` are the live post-GTFS sources). It answers "which routes touch these seed stages", not "am I on my route". No reason to keep it.

### Pair 4: `stage_geofence_engine` (journey) vs `stage_detection_engine` (matatu)

- journey: stateful geofencing — holds `_activeStages`, emits `entered` (≤50 m) / `approaching` (≤200 m) / exit events via `StageDatabase.findNearbyStages` (stage_geofence_engine.dart:44-97).
- matatu: stateless query helper — nearest within 500 m / in-radius sorted (1000 m) / by-corridor over **`SeedData`** (stage_detection_engine.dart:7-38).

**Verdict: partial overlap (helper subset + engine).** The matatu version is a weaker, stale-data copy of what `StageGeofenceEngine` (via `StageDatabase`) and `findNearbyStages` already do. No unique value; delete.

---

## Part D — Files with no counterpart

| File | Analysis | Action |
|---|---|---|
| `journey_auto_detector.dart` | Unique orchestrator — the live spine of the whole journey feature. | **Keep unchanged.** |
| `stop_progress_engine.dart` | Unique stop-rung tracker; the only consumed "next stage" source (see Part E). | **Keep**; add tests. |
| `route_deviation_engine.dart` | Unique (wrong-direction + off-route). No matatu counterpart. | **Keep**; repair coord input (Part E). |
| `fare_estimation_engine.dart` (matatu) | Unique in the engine folders, but **duplicates live `FareCalculatorService`** — which is the spec-canonical path (`docs/TRANSPORT_DATA_SPEC.md` §1: verified `fare_estimate` row → `FareCalculatorService`, never raw 0.0). Its formula (`base 50 + 10/km`) conflicts with the tiered service (tests: short [20–50], long 100/150). | **Delete** (+ its `widget_test.dart` group). |

---

## Part E — FSM coverage map

Reference states (§2 of the spec): `WALK_TO_PICKUP → WAITING_OR_BOARDED → ON_MATATU → WALK_TO_FINAL_DESTINATION`.
The 8-value `JourneyPhase` (journey_models.dart:1-10) maps: `walkingToStage` ≈ WALK_TO_PICKUP; `waitingForMatatu` ≈ WAITING_OR_BOARDED; `riding` + `approachingDestination` ≈ ON_MATATU; `alighting` + `finalWalking` ≈ WALK_TO_FINAL_DESTINATION (+`beforeTravel`/`journeyComplete` envelope).

| Spec state | Producers | Consumers | Transit out | Gaps |
|---|---|---|---|---|
| WALK_TO_PICKUP | `BoardingEngine` (walking class), `GeofenceEngine` (approach/entered events) | — (geofence events **never read**, see Finding 1) | `BoardingEngine.didBoard` only | Walk-to-pickup leg has no engine (only `NavigationProvider._checkProgress`). Entry can stall if boarding never fires (Finding 5). |
| WAITING_OR_BOARDED | `BoardingEngine` (board detection) | FSM | inVehicle sustained + conf > 0.6 | No wait-time logic; geofence "arrived" banner unused. |
| ON_MATATU | `StopProgressEngine` (stop rungs), `AlightEngine` (approach/alight), `DevationEngine` (off-route), `RouteMatcher` (identity) | `onStopReached` (FSM), `onApproachingDestination`, deviation callbacks | alight | Three engines each compute "current/next stage" (stopProgress / routeMatcher / geofence); only stopProgress's value is consumed. |
| WALK_TO_FINAL_DESTINATION | `AlightEngine.hasAlighted` (drives transition); `BoardingEngine.didAlight` (computed, **unused**, Finding 2) | FSM | `JourneyProvider` advances `alighting → finalWalking → journeyComplete` by itself | Final-walk leg has no engine progress tracking. |

### Concrete findings (evidence)

1. **Geofence engine runs but its output is thrown away.** `auto_detector:86` `unawaited(_geofence.checkGeofences(lat, lng));` — result discarded. `geofenceEvents` getter (`auto_detector:52`) has **no consumer in `lib/`**. `StageGeofenceEngine.isAtStageName`/`getCurrentStageName` are hardcoded stubs returning false/null (stage_geofence_engine.dart:101-107). So every GPS tick pays for a DB radius query that feeds nothing into the FSM.
2. **Two alight signallers, one consumed.** `BoardingDetectionEngine.didAlight` (boarding:107-117) is never read by the orchestrator — `_detectPhaseTransitions` uses only `didBoard`, `currentState`, `confidence` (auto_detector:97-148). Alighting is owned by `AlightDetectionEngine`; the boarding engine's alight path is dead inside a live file.
3. **Route matching never actually runs during a journey.** `recordPoint` keeps a path (auto_detector:89), but `_routeMatcher.matchToRoutes` is only reached via `JourneyAutoDetector.matchRoute()` (auto_detector:158-163), which **has no caller in `lib/`**. Hence `routeConfidence` (`auto_detector:46`) is always `0` (no `currentMatch`) and route identity / current-stop from the matcher is never produced.
4. **Hardcoded misuse of real coordinates defeats two engines.** `_startAutoDetection` (journey_provider.dart:442-443) passes `startLat: -1.2833, startLng: 36.8167` for **both** branches (the `?:` is identical), i.e. Nairobi city-center constants, and `destinationLat/Lng` = `_destinationPoint` (the searched place), NOT `_toStageLocation` (the alight stage). Consequences: `RouteDeviationEngine._checkWrongDirection` computes a fixed city-center baseline (route_deviation_engine.dart:85-108) → effectively garbage; `AlightDetectionEngine` approaches the final place instead of the alight stage → late/shifted triggers.
5. **State 1 can stall.** `walkingToStage` exits only on `didBoard`, which requires an explicit `walking → inVehicle` transition (boarding:95-105). If tracking starts already in-vehicle (or with a hiccup that never registers a walking sample), the FSM never leaves `walkingToStage`; `waitingForMatatu`'s inVehicle+conf>0.6 path is unreachable from there. No fallback/timeout.
6. **Vestigial loop in `StopProgressEngine.checkProgress`.** The loop at stop_progress_engine.dart:72-82 computes `distanceToUser` but only uses it to refresh the reference point; the per-iteration computed value goes unused.
7. **Spec proximity tiers not met.** Spec's ON_MATATU 1 km / 500 m / 100 m / 50 m "next-stop proximity" chain is partially present (alight 500/100; geofence 200/50/100 — unconsumed) but never delivered as an event chain to the UI; `stopProgress` names next stages but carries no distance tiers.

---

## Recommendation

### Phase 1 — Remove the dormant folder (low risk, do now)
Delete `lib/features/matatu/` (all 5 files) and the two groups in `test/widget_test.dart` (lines 101-128). 

- **Risk: essentially nil to runtime.** No `lib/` reference to any matatu file; only `widget_test.dart` imports two of them. `flutter analyze` will not change; only the two test groups disappear.
- No unique live functionality is lost (Part C/D): odometer → `ActiveJourney` totals; proximity alight → `AlightDetectionEngine` (optionally port a 300 m tier later); stage lookups → `StageDatabase`/`StageRegistry`; route catalog → `RouteDatabase`; fare → `FareCalculatorService` per spec §1 (never raw 0.0).
- This resolves the apparent folder duplication definitively: the "two systems racing" concern is unfounded — there was only ever one live system.

### Phase 2 — Repair the live set (medium risk, TEST-FIRST)
Surviving journey engines have **zero automated tests today**; the matatu folder is what the tests cover (only 2 groups). Before any behavior-affecting change, add unit tests for boarding / alight / stopProgress / deviation transitions. Then:

1. Fix Finding 4: pass `_fromStageLocation` / `_toStageLocation` real coords into `startDetection` (deviation + alight become correct).
2. Resolve Finding 1: either wire geofence `entered`/`approaching` into the WALK_TO_PICKUP/WAITING banners, **or** drop `StageGeofenceEngine` and let boarding+stopProgress+alight own the FSM (recommended — removes an engine whose output is currently unused).
3. Resolve Finding 3: call `_autoDetector.matchRoute(_routeNumber)` at journey start (or feed `orderedStages`) so `routeConfidence`/current-stop from the matcher are real; decide whether stopProgress or routeMatcher is the single "next stage" authority.
4. Resolve Finding 5: add a fallback (timeout or `score-based` induction into ON_MATATU) so state 1 cannot stall.
5. Resolve Finding 2: drop `BoardingDetectionEngine.didAlight` (or own alighting with it exclusively) to kill the dual-signal dead output.

### Risk summary
- Phase 1: negligible (deletes only orphaned code; one test file edited).
- Phase 2: moderate — it changes live detection behavior (coordinate inputs, geofence consumption, route-matcher activation) and the journey feature has no engine-level tests to catch regressions; hence the test-first gate.

---

## Part F — Phase 2 execution trail (test-first, one defect at a time)

Each defect: red test written first → fix → green → full suite (`flutter test --no-pub`).

1. **Finding 1 — geofence output discarded.** RED `stage_geofence_engine_test.dart` (`isAtStageName` stub returned false). Fix: `StageGeofenceEngine` real `_activeStageNames` tracking + `isAtStageName`/`getCurrentStageName`; orchestrator `walkingToStage` exits on pickup-stage `entered` → `waitingForMatatu`; new `onStageArrived` → provider `advancePhase(waitingForMatatu)`. Added `configureEngine`/`processSample` test hooks + lazy `StageDatabase._db` (Firebase-free unit tests). 179 → 182.
2. **Finding 2 — didAlight dead (unreachable + unread).** Probe proved unreachability (never fires across 5 profiles). RED `journey_auto_detector_alight_fallback_test.dart`: FSM must reach `alighting` via movement-state fallback when the geo engine can't confirm (ride far from the alight stage, then sustained walking) — failed `riding`. Fix: boarding latch uses consecutive-tick counters (`_rideTicks`/`_alightWalkTicks`), making `didBoard`/`didAlight` reachable; orchestrator `riding`/`approachingDestination` now consumes `boardingResult.didAlight` as alight fallback. 182 → 183.
3. **Finding 3 — route matcher never runs.** RED `journey_auto_detector_route_match_test.dart`: riding route 44 (Kencom→…→Kasarani, real coords) leaves `routeConfidence` 0. Fix: optional `routeNumber` on `configureEngine`/`startDetection`; orchestrator auto-runs `matchRoute` on first `riding` sample; provider passes `_routeNumber`. 183 → 184.
4. **Finding 4 + destination-alight (the two coordinate defects) — shared seam.** `_startAutoDetection` passed hardcoded `-1.2833, 36.8167` for BOTH start branches and sent `_destinationPoint` (place) as the alight target. Extracted `resolveAutoDetectionCoordinates()` mirroring current values; RED `journey_provider_coordinates_test.dart` asserted start == pickup stage and dest == alight stage (failed: `-1.2833`). Fix: seam returns `_fromStageLocation`/`_toStageLocation`. Removed unused Firebase-constructing `_predictor`/`_reportService` fields blocking provider construction in tests (−2 analyzer warnings). 184 → 185.
5. **Finding 5 — State-1 stall.** RED `journey_auto_detector_stall_test.dart` (ride-only tracking, pickup geofence never entered) **passed on first run**: the reachability repair in step 2 (`didBoard` on 3 consecutive in-vehicle ticks) already un-stalls the FSM (State 1→3 via didBoard→waitingForMatatu→riding). No code change was warranted (the elected explicit fallback would have been redundant); kept as regression guard. 185 → 186.

Final state: 186 tests pass; `flutter analyze` 0 errors / 229 issues (down from 232 baseline: −2 unused fields, net of new test lints). Defects #1 and #6 share the `walkingToStage` exit path (geofence + boarding induction); #2 is the reachability repair (not merely a deletion); #5 is independent of #2/#6 (wrong coordinate anchor, fixed with #4 via the shared seam).

---

## Verification (this audit)

- No `lib/**/*.dart` file was created, modified, or deleted at audit time; the audit itself was read-only. (Superseded by Phases 1–2: Phase 1 deleted `lib/features/matatu/engines/` + 2 `widget_test.dart` groups; Phase 2 modified `lib/features/journey/engines/` — `boarding_detection_engine.dart`, `stage_geofence_engine.dart`, `journey_auto_detector.dart` — plus `lib/providers/journey_provider.dart`, `lib/data/databases/stage_database.dart`; see Part F.)
- `git status --short` at audit time showed only pre-existing untracked files (`TRANSPORT_DATA_SPEC.md`, `hint2.dart`, `test/services/corridor_resolver_test.dart.bak`); the only new artifact was this report.
- `flutter analyze` baseline: 0 errors / 232 info-warning issues → post-Phase-1 231 → post-Phase-2 229.
- `flutter test --no-pub`: 183 passed at audit → 179 after Phase 1 (dead groups removed) → 186 after Phase 2 (+7 tests).