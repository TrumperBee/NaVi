# NaVi Transport Data Specification
**Version 1.0 — October 2026**

This document defines, precisely, what a "place," a "stage," a "route," a "direction," and a "fare estimate" are inside NaVi; how they relate to each other; how IDs work; how the app decides what to trust when two sources disagree; and how a non-technical contributor's work turns into data the app actually uses. It supersedes informal discussion — if code and this document disagree, this document is correct until explicitly revised.

This spec reflects three converged inputs: the schema proposal reviewed with ChatGPT and Gemini, the 4-state journey model both arrived at independently, and the real structure/quality issues found by actually importing and cleaning the Digital Matatus GTFS feed (2,771 deduplicated stages, 271 route-direction records, 176 names flagged for human review). Nothing from that review is dropped here — where I diverged from either AI's proposal, the reasoning is stated explicitly rather than silently substituted.

---

## 1. Core Entities

### 1.1 Place
A **place** is anywhere a person might want to go or start from. It is not necessarily a transit stop. A place can be an area ("Roysambu"), a landmark ("TRM", "Kenyatta National Hospital"), a building, or an institution ("University of Nairobi, Chiromo Campus").

| Field | Type | Required | Notes |
|---|---|---|---|
| `place_id` | string | yes | See §4 ID conventions |
| `name` | string | yes | Canonical display name |
| `aliases` | string[] | no | Alternate names/spellings a search should also match |
| `type` | enum | yes | `area`, `landmark`, `institution`, `building` |
| `latitude` / `longitude` | double | yes | |
| `source` | enum | yes | `gtfs_import`, `contributor`, `mapbox_geocode` — see §5 |
| `confidence` | enum | yes | `verified`, `unverified`, `disputed` — see §6 |

A place is **not** required to have a stage. "Roysambu" the area exists as a place independent of "Roysambu Stage" the boarding point. This is the correction both reviewing AIs converged on, and the GTFS import confirmed why it matters: the raw feed contains 4,284 stop records, several of which share a name with an unrelated place elsewhere in the city (e.g. "Shell," "Tuskys," "Junction" each appear dozens of times as genuinely different physical locations). Collapsing "place" and "stage" into one concept makes that ambiguity unsolvable; keeping them separate makes it a straightforward lookup.

### 1.2 Stage
A **stage** is a specific, physical matatu boarding/alighting point. Every stage is implicitly a place, but the reverse is not true.

| Field | Type | Required | Notes |
|---|---|---|---|
| `stage_id` | string | yes | See §4 |
| `stage_name` | string | yes | |
| `place_id` | string | no | Links to the parent place/area if one exists; null is valid (a stage can exist without a named parent area being modeled yet) |
| `aliases` | string[] | no | |
| `latitude` / `longitude` | double | yes | |
| `road` | string | no | The road/corridor this stage sits on |
| `direction_hint` | string | no | e.g. "towards CBD" / "towards Thika" — disambiguates stages that serve opposing directions of the same road |
| `routes_served` | string[] | yes | Route numbers, derived automatically from `route_stops` (§1.4) — never hand-maintained, always computed |
| `source` | enum | yes | Same as place |
| `confidence` | enum | yes | Same as place |
| `member_stop_ids` | string[] | no | Audit trail only — original GTFS `stop_id`s merged into this canonical stage. Not used at runtime. |

This directly maps onto the existing `StageRecord` Dart model already in the codebase (`stageId`, `stageName`, `latitude`, `longitude`, `routesServed`, `area`). No model rewrite is needed — this spec formalizes the contract that model already implements.

### 1.3 Route
A **route** is a matatu service identified by a route number (e.g. "58," "34B"), independent of direction.

| Field | Type | Required | Notes |
|---|---|---|---|
| `route_id` | string | yes | |
| `route_number` | string | yes | As painted on the vehicle / known colloquially — this is what a rider searches for, not `route_id` |
| `route_name` | string | yes | Descriptive, e.g. "Ambassadeur–Jogoo Road–Buruburu" |
| `corridor_id` | string | no | See §1.5. **Must be allowed to be null/`unassigned`** — see Design Note below |
| `sacco` | string | no | Operator, where known |

**Design note — why `corridor_id` is optional, not required:** The GTFS import attempted automatic corridor assignment by keyword-matching route names against 8 known corridors (Ngong Road, Thika Road, Mombasa Road, Waiyaki Way, Jogoo Road, Langata Road, Outer Ring Road, Kangundo Road). After fixing two real matching bugs (a GTFS misspelling of "Allsops" as "Alssops," and recognizing Kangundo Road as Jogoo Road's continuation), 80 of 271 route-direction records still legitimately fell outside the 8-corridor model — Kiambu Road, Embakasi/Utawala, and several CBD-south short routes have no corridor defined yet. A route with no corridor must still function (walk → direct ride → walk, no corridor-dependent features like named-corridor search), not block journey-building. This was verified directly: two unassigned routes (114R Limuru↔Ngara, 100 Kiambu↔OTC) both produce complete, sane journeys through the existing direct-ride fallback. **Corridors are an enrichment, not a dependency.**

### 1.4 Direction & Route Stops
Nairobi transit is not symmetric — the same road can have different boarding/alighting behavior depending on direction (a one-way system near a terminus, a stage that only serves outbound riders, etc.). NaVi therefore models **direction as a first-class concept**, not an assumption.

**`directions`** (one row per route per direction):
| Field | Type | Required | Notes |
|---|---|---|---|
| `direction_id` | string | yes | Scoped to a route: `{route_id}_0`, `{route_id}_1` |
| `route_id` | string | yes | |
| `headsign` | string | yes | Human-readable destination shown to riders, e.g. "Kahawa West" |

**`route_stops`** (the ordered sequence — "probably the most important table," per the original review, and confirmed in practice: this is exactly what the GTFS `stop_times.txt` import produced and what `RouteBuilderService` consumes directly):
| Field | Type | Required | Notes |
|---|---|---|---|
| `direction_id` | string | yes | |
| `stage_id` | string | yes | |
| `stop_order` | int | yes | 1-indexed position along this direction |

A `RouteRecord` in the Dart codebase is one direction (this is why the GTFS import expanded 136 routes into 271 `RouteRecord`s — one per direction, consistent with `startStage`/`endStage`/`orderedStages` already being direction-flat fields on that model, not route-flat ones).

### 1.5 Corridor
A **corridor** is a named grouping of stages/routes along a shared major road, used for search disambiguation ("Muchai Drive" → nearest corridor "Ngong Road" → nearest stage) and for corridor-based contributor assignment (§7). A corridor is an index/convenience structure over stages and routes, not a source of truth for either.

### 1.6 Fare Estimate
NaVi has **two fare mechanisms, and they are not in conflict — they serve different purposes and must stay separate:**

1. **Computed fares (default, always available):** `FareCalculatorService` computes a fare at query time from distance tier + time-of-day, rounded to standard denominations (`FareMatrix`). This requires no data entry, works for every route including brand-new or unassigned-corridor ones, and is what ships today. **This remains the default for every route that has no verified real-world fare on file.**
2. **Verified fare estimates (override, contributor-sourced):** where a contributor has reported an actual observed fare for a specific `(route_id, from_stage_id, to_stage_id)` pair, that value should be preferred over the computed estimate, because real matatu fares deviate from a clean distance formula (negotiated, surge-priced in rain/rush, route-specific quirks). This is exactly what the existing `fare_intelligence` community service was built for — it should be the thing that populates this table, not a new separate system.

| Field | Type | Required | Notes |
|---|---|---|---|
| `route_id` | string | yes | |
| `from_stage_id` | string | yes | |
| `to_stage_id` | string | yes | |
| `estimated_offpeak` | int | yes | KSh, standard denomination |
| `estimated_peak` | int | yes | KSh |
| `confidence` | enum | yes | |
| `last_verified` | date | yes | |
| `reported_by` | string | no | Contributor/user attribution for trust scoring |

**Resolution order when displaying a fare:** verified `fare_estimate` row for this exact `(route, from, to)` → `FareCalculatorService` computed value. Never the raw `0.0` placeholder a `RouteRecord` may carry (this was explicitly audited after the GTFS import — confirmed zero UI paths read the unset field directly, and that must remain true as fare estimates are added).

---

## 2. The Journey Model (4-State FSM)

This is the single most important piece of shared understanding between your own original description (UoN/Chiromo and I&M Bank examples) and both AI reviews — all three converged on the same structure independently, which is a strong signal it's correct, not just convenient.

```
[SEARCH]
   │ user selects a destination PLACE (may or may not be a stage)
   ▼
[STATE 1 — WALK_TO_PICKUP]
   │ walking polyline: user's current location → nearest/selected boarding STAGE
   │ geofence trigger at arrival (≈40m)
   ▼
[STATE 2 — WAITING_OR_BOARDED]
   │ banner: "At {stage}. Board any {route} matatu to {headsign}."
   │ transition trigger: explicit user tap ("I've boarded") OR speed-based
   │   auto-detection (sustained speed > ~25 km/h along the known corridor)
   ▼
[STATE 3 — ON_MATATU]
   │ Uber-style live tracker: speed, distance/time remaining, next stage
   │ proximity alerts at 1km / 500m / 100m / 50m before alighting stage
   ▼
[STATE 4 — WALK_TO_FINAL_DESTINATION]
   │ walking polyline: alighting STAGE → final destination PLACE
   ▼
[JOURNEY COMPLETE]
```

**Why this belongs in the spec and not just in code comments:** the existing codebase currently has two parallel engine folders (`features/journey/engines/` and `features/matatu/engines/`) independently attempting pieces of this same state machine — boarding detection, alighting detection, route deviation, stage geofencing — without a single shared contract between them. That duplication is a direct symptom of this FSM never having been written down as the canonical model before code was written against it. Any future engine work should implement *this* state machine, explicitly, rather than re-deriving it per-engine. Reconciling/consolidating the two existing engine folders against this FSM is a follow-up task, not something this spec resolves by itself — flagging it here so it isn't lost.

**Multi-leg journeys:** State 2→3→4 can repeat if a journey requires a transfer (no direct route exists between origin and destination stages). In that case, State 4's "final destination" for an intermediate leg is actually the next boarding stage, and the FSM re-enters State 1 (now a short inter-stage walk rather than an initial walk) before repeating. This is already how `RouteBuilderService` models multi-corridor journeys (transfer walk segments) — this spec confirms that pattern as correct and canonical, it does not change it.

---

## 3. Search Resolution Order

When a user types a query, NaVi resolves it in this fixed order — never reshuffled per-feature, so behavior stays predictable:

1. **NaVi indexed places** (exact/fuzzy name + alias match)
2. **NaVi indexed stages** (same)
3. **Firestore community-contributed data** (places/stages added by contributors since the last bundled release, not yet in the shipped app binary)
4. **Mapbox Geocoding API** (external, general-purpose — knows *where* something is, not that NaVi has transit knowledge about it)

**Why this order, specifically correcting Gemini's original proposal:** Gemini's version put Firestore ahead of local indexed data unconditionally ("local/Firestore stages first → Mapbox if fewer than 3"); the order above keeps bundled/offline data as the first two checks specifically so search still works with no network connection, which matters for a commuter app in areas with inconsistent signal — Firestore is a network call, bundled data is not.

**The Mapbox fallback does not stop at "found a coordinate."** When Mapbox resolves a place NaVi has no transit knowledge about (e.g. Kenyatta National Hospital, if not yet in the stage/place index), NaVi must chain immediately into: resolved coordinate → nearest indexed stages (§1.2, via `CorridorResolver`) → present those as the boarding options. A bare coordinate with no transit path attached is not a useful search result for this app.

**On the "free places API" question raised early on:** Mapbox's Geocoding API (100,000 free temporary-geocoding requests/month, confirmed as of this writing) comfortably covers live search-as-you-type for the near future at NaVi's scale. One nuance worth stating explicitly since it wasn't flagged by either reviewing AI: that free tier covers *temporary* geocoding (a live search session); *permanently storing* a large, growing volume of geocoded results is a separate, paid product. This doesn't affect current features (saving a user's Home/Work/Campus is a handful of stores per person, negligible under either pricing model) — it only matters if a future feature starts bulk-caching geocode results at scale, and is noted here so that decision is made knowingly, not accidentally.

---

## 4. ID Conventions

| Entity | Format | Example | Rule |
|---|---|---|---|
| `place_id` | `PL` + zero-padded sequence | `PL0001` | Assigned once, never reused, never reassigned even if the place is later merged/deleted |
| `stage_id` | slug of canonical name, `_N` suffix if the name collides with another canonical stage in a different location | `makadara`, `riverside_2` | Matches the convention already produced by the GTFS import script — not a new scheme |
| `route_id` | carried through unchanged from GTFS where sourced from it; `R` + sequence for contributor-submitted new routes | `40601005811` (GTFS-sourced), `R0137` (new) | Never reformatted — GTFS IDs are opaque but stable, don't "clean them up" |
| `direction_id` | `{route_id}_{0 or 1}` | `40601005811_0` | |

IDs are **never reused** after a merge or deletion. If two stages are later discovered to be the same physical place and merged, the deprecated ID is kept in a redirect table (`merged_into: <surviving_id>`) rather than deleted outright — this preserves the integrity of any historical journey records or external references that used the old ID. This is a direct lesson from the GTFS import: the import script already does this (`stages_trace.json` keeps every original GTFS `stop_id` mapped to its surviving canonical `stage_id`) — this spec generalizes that same pattern to all future merges, not just the initial bootstrap.

---

## 5. Data Sources & Precedence

NaVi's transit data comes from three sources, and when they disagree, this is the resolution order (most to least trusted):

1. **Verified contributor data** (`confidence: verified` — reviewed and confirmed by Victor or a designated trusted reviewer)
2. **GTFS bootstrap data** (`source: gtfs_import` — real, field-surveyed, but from 2019 and already known to contain the naming collisions documented in `review_priority.csv`)
3. **Unverified contributor data** (`confidence: unverified` — submitted but not yet reviewed)
4. **Live Mapbox geocode result** (not persisted as transit data at all — used only for the search fallback in §3, never written into the places/stages tables directly)

A contributor correction to an existing GTFS-sourced stage does not delete the GTFS record — it adds a new `source: contributor` record and, once verified, that record's coordinates/name become what the app displays, while the original GTFS record is retained for audit (consistent with the ID-retirement rule in §4).

---

## 6. Contributor Pipeline

### 6.1 Why not a PDF
A PDF was the original idea for a non-technical format friends could fill in. It's a reasonable way for one person to privately draft what they already know, but it fails specifically at the *multi-contributor* part of this problem: no structure to validate against, no way to programmatically merge five people's independent PDFs, and no mechanical way to catch "Roysambu" / "ROYSAMBU" / "Roys" / "Roysambu Stg" as the same entity. A structured, columned spreadsheet solves exactly the part a PDF can't. This is not a reversal of the original PDF instinct — the underlying goal (something a non-coder can fill in without touching Dart) is preserved; the format is what changes.

### 6.2 Format: Google My Maps, not a custom web form
Between the two concrete proposals reviewed (a custom pin-drop web form vs. Google My Maps), **Google My Maps is the right choice for this stage**, for a direct reason: a custom form is a second application to design, host, and maintain, and every hour spent on it is an hour not spent on NaVi itself. My Maps is zero-code, friends already know how to use it, pin-dropping gives exact coordinates with no typo risk, and it exports directly to KML/CSV. The custom form remains a legitimate future upgrade if My Maps becomes an actual bottleneck at higher contributor volume — not before.

### 6.3 Corridor-based assignment
Each contributor is assigned one corridor (Thika Road, Kangundo Road, Jogoo Road, Ngong Road, Waiyaki Way, Mombasa Road, Langata Road, Outer Ring Road, plus any newly-recognized ones per §1.3's design note) rather than being asked to document "Nairobi" in general. Within their corridor, each contributor's My Maps layer is **pre-populated from the GTFS import** (the relevant subset of the 2,771 already-deduplicated stages) rather than started blank — their task becomes *verify, correct, and fill gaps*, not *enumerate from nothing*. This is a direct, concrete consequence of the GTFS import's success: it changes contributors' actual workload from "document everything" to "review what's already there," which is both a smaller ask and produces higher-quality results than asking someone to recall every stage from memory.

Each contributor's layer should specifically flag, for their corridor, any rows present in `review_priority.csv` — a Nairobi local looking at "Makadara" plotted near Kitengela will recognize that's wrong instantly, in a way no automated script can.

### 6.4 Required columns (contributor-facing sheet)

| Column | Required | Purpose |
|---|---|---|
| Stage/Place name | yes | |
| Corridor | yes | Pre-filled per contributor assignment |
| Pin location (from My Maps export) | yes | Lat/lng, auto-populated by export, never hand-typed |
| Route numbers served | yes | |
| Notes | no | Free text — local names, caveats, anything structured columns don't capture |
| **Contributor** | yes | Name/identifier |
| **Date submitted** | yes | |
| **Verified** | system-set | Not editable by contributors — set during review |
| **Verified by** | system-set | |
| **Confidence** | system-set | `verified` / `unverified` / `disputed` |
| **Last updated** | system-set | |

**Explicitly avoid an unrestricted, fully-open-edit sheet** — this was flagged as a real risk in the original review (five variant spellings of the same stage from five different contributors), and the GTFS import independently demonstrated exactly this failure mode already exists even in a single professionally-surveyed dataset (4,284 raw records → 2,773 after dedup, 176 names still needing human judgment). An open sheet with multiple non-technical contributors will reproduce and likely worsen this problem without the structure above.

### 6.5 Pipeline

```
CONTRIBUTORS (friends, one per corridor)
        │  fill in pre-populated Google My Maps layer + linked sheet
        ▼
VALIDATION PASS (you, or a designated trusted reviewer)
        │  check against review_priority.csv-style flags,
        │  mark Verified / Confidence, reject obvious errors
        ▼
   ┌────┴────┐
   ▼         ▼
FIRESTORE   LOCAL JSON (bundled)
(live,      (offline-first, shipped
 incremental) in the next app release)
   └────┬────┘
        ▼
   NaVi Data Engine
   (places / stages / routes / route_stops / fare_estimates)
        │
        ▼
   Route Engine  →  Mapbox (walking/visual only)  →  User
```

This is unchanged from the original reviewed proposal — it was correct — formalized here with the validation step made explicit as a required gate, not an optional nicety, and with the GTFS import's proven dedup/validation logic (§7) as the concrete mechanism behind "Validation Pass," rather than a vague manual step.

---

## 7. Data Quality Rules (codified from the GTFS import, binding for all future imports — contributor or otherwise)

These aren't just facts about what the import script happened to do — they are standing rules any future data ingestion (a re-run import, a Firestore sync, a contributor batch merge) must also follow:

1. **Stage deduplication:** candidate duplicates are grouped by normalized name, then clustered by proximity. Stages within **250m** of each other sharing a name are merged into one canonical stage. This threshold is a starting default, not sacred — revisit if a future review finds it merging genuinely distinct nearby stages, or failing to merge true duplicates.
2. **Outlier flagging, never silent auto-merge:** same-name stages farther apart than **1,500m** are never automatically merged — they're flagged for human review and kept as separate entities until a person confirms. A same-named stage 15km away is far more likely a naming collision than an error.
3. **Generic names are expected to repeat and are not inherently errors:** branded/generic names (Shell, Total, Junction, Garage, Car Wash, Mosque, and similar) legitimately recur across unrelated physical locations city-wide. A review/flagging process should filter these out of the "needs human attention" list rather than burying genuine issues under expected noise — this cut the GTFS review list from 603 to a genuinely actionable 176.
4. **Never import with a dangling reference.** If any route's stop sequence references a stage ID that doesn't exist in the resolved stage set (e.g. from a dedup that dropped rather than redirected an ID), the import must refuse to complete — log the failure, make no partial write, and preserve whatever data was previously in place. This is a direct, binding consequence of a real near-miss found during the GTFS integration (two dropped duplicate IDs that happened not to be referenced by any route, but could have been) — it is now enforced in code (`gtfs_import_service.dart`) and this spec makes it a standing requirement for any future import path, not a one-off fix.
5. **ID retirement, not deletion**, per §4 — merged/dropped IDs are redirected and traceable, never silently vanish.

---

## 8. What This Spec Deliberately Does Not Cover Yet

Stated explicitly so it isn't mistaken for an oversight:

- **Corridor-level route geometry** (actual road-following polylines) — this exists in the GTFS `shapes.txt` file (36,483 points) but was out of scope for the stages/routes import completed so far. A future, separate pass should import this to replace the hand-drawn corridor polylines currently in `nairobi_corridors_seed.dart`.
- **Reconciling the two existing parallel engine folders** (`features/journey/engines/` vs `features/matatu/engines/`) against the FSM in §2 — flagged in §2 as necessary follow-up, not resolved by this document itself.
- **A formal schema/ERD for `calendar`/`calendar_dates`-equivalent scheduling** — matatus don't run fixed schedules, so NaVi correctly has no use for GTFS's time-tabled service-calendar concept; `frequencies.txt`-style headway ranges (already imported) are the right analog, not a schedule table.

---

*This document should be re-versioned, not silently edited, when a structural change is made (a new required field, a changed precedence rule, a new entity). Minor corrections (typos, clarifications) don't require a version bump.*
