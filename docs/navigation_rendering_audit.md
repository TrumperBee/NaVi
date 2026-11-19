# Navigation Rendering Audit

Scope: diagnostic-only audit of three reported navigation bugs. No code was
changed. Everything below is traced to code as it exists in this repo.

Audit date: 2026-10-07

| # | Symptom | Verdict | Root subsystem |
|---|---------|---------|----------------|
| 1 | Rendered route is a straight line, no road-following geometry anywhere | Confirmed defect | Graph/OSRM polyline pipeline (+ corridor stage-assignment gap) |
| 2 | Maneuver text is wrong ("Walk 50m to Kenyatta Avenue" style) | Confirmed defect | Graph instruction generator |
| 3 | Landmark search returns nothing | Wired but disabled by build config | Mapbox token injection (Dart define) |

Symptoms 1 and 2 share a root cause (the pathfinding-graph pipeline). Symptom 3
is an independent root cause and does not cause 1 or 2. Details below.

The definitive question — which pipeline actually runs when a user taps
"Navigate" / "Start Journey" — is answered in the top section below
("Live Pipeline Topology"). The later per-symptom sections document the
internals of each engine; that top section is authoritative about which one
is on screen at any moment.

---

## Live Pipeline Topology — What Actually Runs When a User Navigates

### Verdict

Both systems are **live** on the single reachable navigation UI (the
auth-gated `HomeScreen`) and they **cooperate in a fixed, sequential handoff —
they do not race**:

- The **graph system** (`NavigationProvider` + `PathfindingService` +
  `NavigationService`) is the *route-planning / path-option engine*. It runs
  when the user picks a destination ("Navigate"), produces the candidate
  `PathOption`s (route numbers, heuristic fares, times) and feeds the handoff
  coordinates.
- The **corridor system** (`RouteBuilderService` → `CorridorResolver` →
  `RouteSegment` → `FareCalculatorService` → `PolylineRendererService`/
  `ActiveJourneyViewModel`) is the *journey-execution engine*. It owns every
  artifact the rider actually sees: the pre-trip line, the pre-trip summary
  (walk/ride split, duration, fare), the live HUD instruction text, voice, and
  the completed-trip record.

All of this happens on `HomeScreen` (`lib/main.dart:86-96`). `MainMapScreen`,
the only place that renders graph `InstructionStep`s, is registered as route
`/map` (`lib/main.dart:111`) but is **unreachable** — no `Navigator` code in the
repo pushes `/map` (verified: only `main.dart` mentions it). Its graph-only
navigation flow (`lib/screens/main_map_screen.dart:147-190, 327, 374`) is dead
UI today. `/search` (`DestinationSearchScreen`, `lib/main.dart:99`) is likewise
registered but never pushed.

### 1. Entry points and exact call chains (all on HomeScreen)

The "Navigate" and "Start Journey" buttons are **sequential phases of one
flow**, each invoking one of the two engines:

**Phase A — "Navigate" → graph planning:**
- Stage Details sheet's "Navigate" button (`lib/screens/stage_details_sheet.dart:377-382`
  → `_handleNavigate` `:143-146`) → `onNavigate` → `home_screen.dart:368`
  (`_showStageDetails`) → `_startNavigation` (`home_screen.dart:380-393`) →
  `NavigationProvider.startNavigation` (`lib/providers/navigation_provider.dart:218`)
  → `_calculateTransportRoute` (`:240`) → `findBestRoutes` (`:249`) → first
  `PathOption` selected (`:259`), straight polyline built (`:261`, `:288-295`),
  graph instructions loaded (`:263`) — then graph instruction list is **not
  rendered anywhere on this screen**.
- Same entry (`_startNavigation`) is used by Quick Go (`home_screen.dart:801`),
  SearchOverlay results (`:1098`), famous-route matches (`:1686`) and popular
  destinations (`:1698`).

**Phase B — pre-trip takeover → corridor preview:**
- Once `isNavigating && selectedPath != null` (`home_screen.dart:675-688`),
  a post-frame callback runs `_ensureConfirmedRoute` (`home_screen.dart:537`),
  which calls `RouteBuilderService.build(...)` (`:551`). On success it sets
  `_confirmedJourney` and calls `_polylineRenderer.renderJourney(preview: true)`
  (`:577-585`). From that moment the corridor renderer owns the on-map line
  (`_polylineRendererOwnsActiveRoute`, `:70-71`), and the legacy path connectors
  are suppressed (`:423-432`).

**Phase C — "Start Journey" → corridor execution:**
- The pre-trip bar's button (`home_screen.dart:1341-1345`) → `_startJourney`
  (`:455`). It starts the legacy `JourneyProvider.startJourney` in parallel for
  backward compatibility (`:464` — decorative; its connector drawing is disabled
  by the renderer-ownership flag), then hands to `ActiveJourneyViewModel`:
  `startJourneyWith(_confirmedJourney)` (`:510`) reusing the already-built
  corridor journey, or `startJourney` (`:517`) → `RouteBuilderService.build`
  again (`lib/viewmodels/active_journey_viewmodel.dart:63`).
- Live screen = `NavigationOverlay` (`home_screen.dart:719-754`) fed by
  `_activeJourneyVM.activeJourney`; `ManeuverBanner` + `JourneyInfoPanel` render
  `journey.currentSegment.label` (`lib/screens/navigation_overlay.dart:77-79,
  89-94, 146-151`; `lib/widgets/journey_info_panel.dart:184-190`).
- Arrival → `onJourneyCompleted` → `SettingsService.addJourneyRecord`
  (`home_screen.dart:254-258`).

### 2. `RouteBuilderService` call-site classification → LIVE

Live-UI-reachable (4 sites):
1. `home_screen.dart:551` — pre-trip confirmed-route build (fires for any route
   once a `PathOption` exists; a failure degrades to the graph preview,
   `home_screen.dart:586-592`).
2. `active_journey_viewmodel.dart:63` — `startJourney` (live-journey start).
3. `home_screen.dart:517` — call site of the above.
4. `navigation_provider.dart:379` — `selectPathOption` fare recompute,
   reachable from the "Other routes" chips (`home_screen.dart:1586`).

Test-only: `test/services/route_builder_service_test.dart` (13 builds spanning
`:51-327`) and `test/services/gtfs_import_service_test.dart` (`:151, :195, :237`).

No dead production call sites. `RouteBuilderService` is definitively the live
journey-execution engine.

### 3. The graph does NOT read GTFS — it runs on Firestore/Seed data

The graph's stage universe is **not** the GTFS-imported one:
- `setStages` feeds `initializeGraph(stages, [])`
  (`navigation_provider.dart:108-111`); the stage list is the Firestore
  `stages` collection as `StageModel`s (`lib/services/database/database_service.dart:20,
  59-65`), streamed in at `home_screen.dart:332-341`, with `SeedData.getStages()`
  as the fallback (`navigation_provider.dart:234, 253`).
- Edges are built purely from `StageModel.routes` string lists — the `routes`
  argument is passed but never read (`lib/services/pathfinding_service.dart:33-41`),
  fares are the heuristic `_estimateFare` (50 KSh + 10/km,
  `pathfinding_service.dart:167-171`), and edges are capped at 30 km with 2 km
  transfer links (`pathfinding_service.dart:56, 101`).
- The GTFS bundle (`assets/data/gtfs_import/{stages,routes}.json`, 136 source
  routes → 271 direction records) is loaded once at startup
  (`lib/main.dart:47` → `GtfsImportService.loadBundledGtfsData`,
  `lib/services/gtfs_import_service.dart:111-163`): it refreshes the Hive stage/
  route cache (`:134-137`) and repoints `StageRegistry` (`:141`). None of that
  flows into `PathfindingService`. Consumers of `StageRegistry` are
  `CorridorResolver` (`lib/services/corridor_resolver.dart:22`) and
  `RouteBuilderService` (`lib/services/route_builder_service.dart:335, 350, 374,
  540-541`). `DestinationSearchScreen` also reads it (`lib/screens/destination_search_screen.dart:37`)
  but that screen is unreachable (main.dart:99, no pusher).

**Therefore**: the entire GTFS / places / `fare_estimates` project reaches real
users **only through the corridor pipeline**. The graph engine runs blind to it
(heuristic fares, Firestore/Seed stops, no `FareEstimateRegistry` anywhere in
`pathfinding_service.dart` / `navigation_provider.dart`).

### 4. Boundary, and consistency at the handoff

Timeline for one live trip:
1. Graph produces `PathOption`s (route numbers, heuristic fares) and the
   straight polyline — rendered for at most one frame.
2. Pre-trip: corridor `_confirmedJourney` replaces the line and drives the
   summary (walk/ride split, durations, `fareTotalKsh` via
   `FareCalculatorService`, `home_screen.dart:1276-1288`); fallback summary
   uses graph fare with a KSh 20 floor for vehicle legs
   (`home_screen.dart:1290-1309`).
3. Live: corridor journey drives HUD, proximity alerts, TTS, and the
   completion record.

Fare correctness in production: pre-trip and live fares both go through
`FareCalculatorService` → `FareEstimateRegistry.findVerified(route, from, to)`
(`lib/services/fare_calculator_service.dart:74`) — so **verified contributor
fares do reach real users**, but only because the corridor pipeline executes the
trip. The graph's `selectPathOption` fare recompute (`navigation_provider.dart:377-397`)
only feeds the option chips (`home_screen.dart:1608`) and the fallback guard.

The seam to watch: the handoff passes `nearestStageName = path.path.last.name`
(a Firestore/Seed graph node name, `home_screen.dart:564-566`) into
`RouteBuilderService`, which resolves it against `StageRegistry` **by name**
(`route_builder_service.dart:334-339`). Any Firestore-vs-GTFS naming mismatch
silently nulls the declared destination stage and falls back to the
boarding-corridor nearest stage (`route_builder_service.dart:326-331`). Because
both universes describe the same Nairobi stops the join usually lands, but it is
an unverified name match — the only true consistency risk at the handoff.

### 5. Reconciliation with the per-symptom sections below

- Symptom 1's "pipeline A" straight-line exposure occurs on the **first frame
  after selection**, before `_ensureConfirmedRoute` replaces the line
  (trigger is post-frame, `home_screen.dart:684-686`), plus any walk-leg
  straightness and corridor-less direct rides in the corridor journey itself
  (`route_builder_service.dart:103-111, 396`).
- Symptom 2's graph-generated "Walk Nm to X" steps are **not rendered on any
  reachable screen** (only `main_map_screen.dart:374`, unreachable). Live
  instructions are the corridor labels — "Walk to X", "Ride Route N to Y",
  "Walk to <destination>" (`route_builder_service.dart:205, 212, 223, 267, 277`)
  — which carry no distances, so the reported "50m"-style text belongs to the
  graph generator documented below, not to the live HUD.

### Recommendation

The **corridor system should be the surviving pipeline**. It is the only one
wired to the GTFS universe (`StageRegistry`), `CorridorResolver`/`PlaceRegistry`,
`FareCalculatorService`/`FareEstimateRegistry`, and it already owns every
live-rendered artifact (line, pre-trip summary, HUD, voice, completion records).
The graph engine's role should be reduced to that of a planning oracle, and it
must stop running blind to the data the corridor engine uses:

1. Feed `initializeGraph` from `StageRegistry` (drop the Firestore/Seed list, or
   feed GTFS shims through `setStages`) so path options reflect the imported
   route universe instead of a stale/different stage set.
2. Replace `_estimateFare` edge fares with `FareCalculatorService` so option
   cards also show contributor-verified fares.
3. Keep `selectPathOption`'s corridor fare recompute but delete its graph
   `InstructionStep` consumption (nothing reachable reads it).
4. Decommission or rewire `MainMapScreen`'s `InstructionCard` flow — it is the
   only surviving surface for graph instruction text.

If both must coexist (graph = planner, corridor = executor), the minimal change
to make them consistent is to pass the resolved GTFS `StageData` identity
(`stage_id`, not a name) through the `SearchResult.nearestStageName` handoff, so
the name-based join at `route_builder_service.dart:334-339` cannot silently miss.

---

## Symptom 1 — Rendered route is a straight line

### Code-traced root cause

Two pipelines can produce the line the user sees. Both have a path that
degrades to straight segments.

**Pipeline A — the map-screen graph polyline (primary cause).**

1. The map screen draws whatever `NavigationProvider` exposes:
   `MapboxLayers.setRoutePolylines(...)` using `remainingRoute ?? routePolyline`
   (`lib/screens/main_map_screen.dart:218-223`).
2. `_routePolyline` is first built purely from the pathfinding graph's node
   coordinates: `_buildRoutePolyline` emits
   `[start, ...option.path node lat/lng..., end]`
   (`lib/providers/navigation_provider.dart:288-295`). Every segment between
   those nodes is a straight chord — there is **no** road or corridor geometry
   in the graph.
3. The graph itself contains only stage points. `setStages` calls
   `_pathfindingService.initializeGraph(stages, [])`
   (`lib/providers/navigation_provider.dart:108-111`) — the `routes` argument
   is always empty, so route/corridor geometry is never loaded into the graph.
   The stage list is whatever Firestore returns (or `SeedData` on failure),
   not even the GTFS corridor stage universe.
4. Road-following is attempted only asynchronously and opportunistically:
   `_improveRoutePolyline()` is called fire-and-forget
   (`navigation_provider.dart:266`) and issues one multi-waypoint OSRM request
   against the public `router.project-osrm.org` server
   (`lib/services/navigation_service.dart:39-70`, `128-156`). It is gated on
   `points.length > waypoints.length` and its error path is a bare
   `catch (_) {}` (`navigation_provider.dart:298-311`). If the public OSRM
   server fails, rate-limits, or returns a degenerate geometry (a very common
   outcome for a 10+ waypoint driving request across Nairobi at runtime), the
   straight node-cord polyline from step 2 stays on screen permanently.
5. The fallback for an empty result is `[start, end]` — a single straight line
   (`_getFallbackRoute`).

So on the map screen the observed default is "straight chords between stages,
no roads anywhere," and road-following appears only when the OSRM improve
pass happens to succeed.

**Pipeline B — the corridor journey pipeline (secondary contributor).**

The home-screen live/pre-trip journey uses `RouteBuilderService`
(corridor slices, real matatu geometry) rather than the graph. Even there, two
paths still render straight:

- **Walk legs are straight by design.** `_createWalkPath(from, to)` returns just
  `[from, to]`
  (`lib/services/route_builder_service.dart:396`). Walking segments have never
  had real geometry.
- **Corridor-less rides collapse.** If either the boarding or alighting stage has
  no corridor (`null` or `''`), `_findCorridorById` returns `null`
  (`route_builder_service.dart:341`) and the trip becomes `_buildDirectStageRide`
  (`route_builder_service.dart:73`, `88`, `104`, `193-...`) — again a straight
  `[from, to]`. GTFS stage corridor ids are only ever assigned by
  route-name keyword → majority-vote → nearest-polyline snap
  (`lib/services/gtfs_import_service.dart:300-341`), and a stage that fails all
  three carries no corridor at all (`_inferCorridor` returns `'unassigned'`,
  `gtfs_import_service.dart:307`; distance snap can also return `''`). The
  committed `assets/data/gtfs_import/stages.json` has no `corridor_id` field, so
  any journey touching an unassigned stage renders straight for those legs.

### Why it manifests end-to-end

Tapping Navigate on the map screen → `startNavigation` →
`_calculateTransportRoute` → graph `findBestRoutes` → straight `_buildRoutePolyline`
→ map draws it immediately (`main_map_screen.dart:218-223`) → OSRM improve fails
silently most of the time → the straight line is what stays. If the user instead
gets a corridor journey on the home screen, walk legs are still straight and any
corridor-less stage makes the whole path collapse to a straight line.

### Interaction with other symptoms

Same subsystem as Symptom 2 (both come from the graph pipeline), independent of
Symptom 3.

### Suggested fix (described, not implemented)

- Make the corridor/GTFS stage universe the single source for the graph, and give
  `initializeGraph` the actual route/corridor geometry so node-cord segments are
  replaced by corridor slices even before OSRM runs.
- Make the OSRM improve pass not best-effort-only: surface failures
  (`onError`) instead of `catch (_) {}`, and gate the route rebuild on an explicit
  success flag.
- Give `_createWalkPath` a real walking-geometry source (e.g. OSRM walking, the
  existing `getOSRMRoute` walking branch) instead of `[from, to]`.
- Resolve the `''`/`'unassigned'` corridor gap so unassigned stages still get a
  geographically snapped corridor.

---

## Symptom 2 — Wrong maneuver/instruction text ("Walk 50m to Kenyatta Avenue")

### Code-traced root cause

The instruction text is generated from the same pathfinding graph as Symptom 1,
and both the distance and the place name are graph artifacts, not real-world
measurements:

1. For every `walk` edge the generator emits:
   `'Walk ${formatDistance(edge.distance)} to ${edge.to.name}'`
   (`lib/services/navigation_service.dart:173-179`).
2. `edge.distance` is the straight-line Haversine between two stage centroids
   (`lib/services/pathfinding_service.dart:52/96`, used by `_addWalkingEdge` at
   `pathfinding_service.dart:258-263`). It is **not** a walked distance along
   roads, so "50m" is a chord length, not a walking instruction.
3. `edge.to.name` is the graph node's name — i.e. another stage's name, or the
   literal string "Your Location" for temporary walking nodes
   (`pathfinding_service.dart:267`). The maneuver therefore reads as a street/building
   ("Kenyatta Avenue" in the report) whenever a transfer stage's name happens to
   look like it, and it never names the user's actual destination.
4. Dijkstra's target is the **nearest stage**, not the destination:
   `_dijkstra(startNode.id, endNode.id, ...)` (`pathfinding_service.dart:215-217`).
   The `walk_end` temporary edge to the real destination
   (`pathfinding_service.dart:212`) is never part of any shortest path because
   the search terminates at the stage. Consequence: the drawn line extends to the
   tapped destination (Pipeline A appends `_endPoint`,
   `navigation_provider.dart:294`), but the turn-by-turn list never contains the
   final walk to the destination at all. The user sees the route end on them but
   no matching instruction.

### Why it manifests end-to-end

The instruction card renders `nav.currentInstructions`
(`lib/features/map/instruction_card.dart`), populated by
`_loadTransportInstructions` → `getTransportInstructions`
(`navigation_provider.dart:313-321`). Those `InstructionStep`s are built from
`PathOption.edges` as above. Every reported oddity — non-road distances, stage
names standing in for streets, a missing final walk — follows directly from the
generator consuming centroid coordinates and stage names instead of measured
geometry and the selected destination label.

### Interaction with other symptoms

Same pipeline as Symptom 1 (the two are different *artifacts* — polyline vs.
instruction list — of the same graph flow). Independent of Symptom 3.

### Suggested fix (described, not implemented)

- Generate walk maneuvers from the walking route (OSRM walking or a street graph
  for the transfer), not from `edge.distance` / `edge.to.name`.
- Re-root the final leg at the destination (Dijkstra over a temp destination
  node) so the "walk the last N m to destination" instruction exists and matches
  the drawn endpoint.
- Use the resolved destination label / location street name for the final walk
  target instead of a stage name or "Your Location".

---

## Symptom 3 — Landmark search returns nothing

### Code-traced root cause

Geocoding **is implemented and fully wired** — this is not a missing feature:

- `lib/services/geocoding_service.dart` calls Mapbox Places v5 forward/reverse
  geocoding (`geocodeMultiple`, `_baseUrl` at line 71; request assembled at
  `106-113` with retry/backoff and typed `GeocodingError`s).
- It is live: `SearchViewModel` runs local + geocode search on every query
  (`updateQuery` → `_runLocalSearch` + `_executeGeocodeSearch`,
  `lib/viewmodels/search_viewmodel.dart:54`, `113-182`), and the search UI used
  by both home and map screens (`SearchOverlay`) calls `updateQuery`.

What is broken is the **token injection**, because the Java/Dart token channel is
empty by default:

- The Dart-side geocoding token is `String.fromEnvironment('MAPBOX_TOKEN',
  defaultValue: '')` (`lib/services/mapbox_config.dart:10-13`). `GeocodingService`
  defaults to it (`geocoding_service.dart:88`).
- In this repo, that define is never supplied: no launch script, CI config, or run
  command passes `--dart-define=MAPBOX_TOKEN=...`, and the committed Android
  `gradle.properties` pins `MAPBOX_TOKEN=` (empty) (`android/gradle.properties:6`).
  The Android native manifest reads a different channel
  (`~/.gradle/gradle.properties` / env, `android/app/build.gradle.kts:36-38`), so
  the *native map SDK* can render while the *Dart HTTP geocoder* still carries an
  empty token.
- With `access_token=` empty, Mapbox responds 401 → mapped to
  `GeocodingError(invalidResponse)` → `_executeGeocodeSearch` lands in the
  `on GeocodingError` branch and keeps only local stage/place matches
  (`search_viewmodel.dart:160-175`).

Local fallback is thin: stage matches come from graph stage names, and curated
places come from a 20-entry seed (`lib/data/nairobi_places_seed.dart`). A
landmark that is neither a stage name nor one of those 20 entries yields an empty
list with a "Geocoding limited — showing local stage matches" / "No results found"
message (`search_viewmodel.dart:145-146`, `168`). That is exactly "searching a
landmark returns nothing."

Note the repo comment anticipates this: "Builds without the define get an empty
token and fail loudly at runtime instead of silently degrading"
(`mapbox_config.dart:8-9`).

### Why it manifests end-to-end

`SearchOverlay` query → `SearchViewModel.updateQuery` → local lookup misses →
geocode HTTP with empty token → 401 → `GeocodingError` → local-only fallback with
no matching local stage/place → empty result list. The feature exists; the build
is missing the Dart define that powers it.

### Interaction with other symptoms

None to 1 or 2 — a failing geocoder only affects *destination selection*, and the
selected coordinates still flow through the same graph pipeline afterward.
(If anything, a 401 geocoder pushes users toward stage/marker clicks, but that
does not change rendering or maneuvers.)

### Suggested fix (described, not implemented)

- Supply `--dart-define=MAPBOX_TOKEN=...` at build time (docs + a run helper), or
  read the token once at startup from the native channel (MethodChannel sharing
  the Android `com.mapbox.token` / iOS `MGLMapboxAccessToken`) so Dart geocoding
  and the native SDK use the same injected token.
- Optionally harden `_executeGeocodeSearch` to still run the corridor pre-release
  search UI hints when geocoding is unavailable.

---

## Connectivity summary

- Symptoms 1 and 2 are the **same root cause** (the pathfinding-graph pipeline)
  viewed through two artifacts: the line drawn (`Pipeline A` straight chords +
  swallowed OSRM improve) and the instruction text (stage-centroid distances and
  stage names). Symptom 1 additionally has independent contributors in the
  corridor pipeline (straight walk legs by design; corridor-less stages collapsing
  to `_buildDirectStageRide`).
- Symptom 3 is an **independent root cause** (empty Dart-side Mapbox token for a
  feature that is otherwise implemented and wired). It is not upstream of 1 or 2.
- There is no single bug behind all three reports; there are two subsystems:
  token/build configuration (3) and the graph geometry + instruction generation
  (1 + 2).

## Consequences for the codebase (information only)

The two pipelines (graph `[start ... stage coords ... end]` served to the map
screen vs. corridor-sliced `RouteBuilderService` journeys served to the home
screen) coexist and produce visibly different geometry for the same trip. Any fix
for 1/2 should consolidate the polyline + instruction source, and should consume
the GTFS/corridor stage universe (see `docs/TRANSPORT_DATA_SPEC.md`) rather than
the Firestore/Seed stage list the graph currently uses.