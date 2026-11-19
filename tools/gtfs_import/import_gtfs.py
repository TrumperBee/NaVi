"""
NaVi GTFS Import & Cleanup Script
Converts Digital Matatus GTFS feed (2019) into NaVi's places/stages/routes/route_stops
seed data, with deduplication of near-duplicate stop entries and an outlier review report.

Input:  the 6 relevant GTFS files (stops, routes, trips, stop_times, frequencies, shapes)
        under raw/ (override with GTFS_RAW_DIR). shapes.txt alone is enough to rebuild
        route_shapes.json; the other five files run the legacy conversion below.
Output:
  - route_shapes.json      (assets/data/gtfs_import/: {route_id}_{direction_id} -> polyline)
  - stages_clean.json      (deduped canonical stages, ready for Dart seed import)
  - routes_clean.json      (routes with ordered stop sequences + fare/duration estimates)
  - review_flagged.csv     (same-name stops that are suspiciously far apart -> needs a human)
  - import_report.md       (summary stats for a human to sanity check before trusting this)
  - shapes_match_report.csv (per route-direction shape mapping detail)
"""
import csv
import json
import math
import os
import re
from collections import defaultdict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.environ.get("GTFS_RAW_DIR", os.path.join(SCRIPT_DIR, "raw"))
OUT_DIR = os.environ.get("GTFS_OUT_DIR", os.path.join(SCRIPT_DIR, "out"))
ASSET_DIR = os.environ.get(
    "GTFS_ASSET_DIR",
    os.path.normpath(os.path.join(SCRIPT_DIR, "..", "..", "assets", "data", "gtfs_import")),
)
os.makedirs(OUT_DIR, exist_ok=True)

# ---------- helpers ----------

def haversine_m(lat1, lon1, lat2, lon2):
    R = 6371000
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
    return 2 * R * math.asin(math.sqrt(a))

def normalize_name(name):
    n = name.strip().lower()
    n = re.sub(r'[^a-z0-9/ ]', '', n)
    n = re.sub(r'\s+', ' ', n).strip()
    return n

def slugify(name):
    s = normalize_name(name).replace('/', '-').replace(' ', '_')
    s = re.sub(r'_+', '_', s)
    return s or 'stage'

# ---------- route_shapes.json: road-following polylines per route+direction ----------
#
# Key format: "<route_id>_<direction_id>" (matches assets/data/gtfs_import/routes.json).
# Value:      ordered [{"lat": ..., "lng": ...}, ...] polyline of the representative
#             trip's shape, oriented in the direction of travel.
#
# Shape -> route-direction mapping:
#   raw/trips.txt present  -> authoritative (trip rows carry route_id, direction_id,
#                             shape_id); longest shape per route+direction wins.
#   raw/trips.txt absent    -> geometric: score every shape against every
#                             route-direction's ordered_stages termini (forward and
#                             reversed endpoint distances), then greedily assign
#                             globally cheapest-first, rejecting matches over
#                             SHAPE_MATCH_MAX_M.
# All coordinates are bounds-checked against the same Nairobi window as stops.txt rows.

SHAPE_BOUNDS = (-1.6, -1.0, 36.5, 37.3)  # lat_min, lat_max, lon_min, lon_max
SHAPE_MATCH_MAX_M = 1500                  # max allowed sum of both endpoint errors
SHAPE_MIN_POINTS = 2                      # fewer surviving points = unusable polyline


def load_shape_polylines():
    path = f"{DATA_DIR}/shapes.txt"
    if not os.path.exists(path):
        return None, {"error": f"shapes.txt not found at {path}"}
    points_by_shape = defaultdict(list)
    stats = {"rows": 0, "rejected_points": 0}
    with open(path, encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            stats["rows"] += 1
            try:
                lat = float(row["shape_pt_lat"])
                lon = float(row["shape_pt_lon"])
                seq = int(row["shape_pt_sequence"])
            except (ValueError, KeyError, TypeError):
                stats["rejected_points"] += 1
                continue
            if not (SHAPE_BOUNDS[0] <= lat <= SHAPE_BOUNDS[1]
                    and SHAPE_BOUNDS[2] <= lon <= SHAPE_BOUNDS[3]):
                stats["rejected_points"] += 1
                continue
            points_by_shape[row["shape_id"]].append((seq, lat, lon))
    polylines = {}
    stats["shape_ids"] = len(points_by_shape)
    stats["dropped_short"] = 0
    for sid, pts in points_by_shape.items():
        pts.sort(key=lambda p: p[0])
        coords = [(lat, lon) for _, lat, lon in pts]
        if len(coords) < SHAPE_MIN_POINTS:
            stats["dropped_short"] += 1
            continue
        polylines[sid] = coords
    stats["points_kept"] = sum(len(v) for v in polylines.values())
    return polylines, stats


def load_route_direction_termini():
    """Route-direction endpoint coordinates from the committed assets (the app's
    stage universe). Returns (termini, skipped_count) or (None, None) if missing."""
    routes_path = os.path.join(ASSET_DIR, "routes.json")
    stages_path = os.path.join(ASSET_DIR, "stages.json")
    if not (os.path.exists(routes_path) and os.path.exists(stages_path)):
        return None, None
    with open(routes_path, encoding="utf-8") as f:
        routes_data = json.load(f)
    with open(stages_path, encoding="utf-8") as f:
        stages_data = json.load(f)
    stage_coords = {s["stage_id"]: (s["latitude"], s["longitude"]) for s in stages_data}
    termini = []
    skipped = 0
    for r in routes_data:
        for d in r.get("directions", []):
            ordered = d.get("ordered_stages") or []
            if not ordered:
                skipped += 1
                continue
            first = stage_coords.get(ordered[0])
            last = stage_coords.get(ordered[-1])
            if first is None or last is None:
                skipped += 1
                continue
            termini.append({
                "key": f'{r["route_id"]}_{d.get("direction_id", "")}',
                "route_number": r.get("route_number", ""),
                "headsign": d.get("headsign", ""),
                "first": first,
                "last": last,
            })
    return termini, skipped


def map_shapes_via_trips(polylines):
    """Authoritative mapping from trips.txt; longest polyline per (route, direction)
    wins as the representative full-route shape. Returns None if trips.txt absent."""
    path = f"{DATA_DIR}/trips.txt"
    if not os.path.exists(path):
        return None
    candidates = defaultdict(list)
    with open(path, encoding="utf-8-sig") as f:
        for row in csv.DictReader(f):
            sid = (row.get("shape_id") or "").strip()
            if sid and sid in polylines:
                candidates[(row.get("route_id", ""),
                            (row.get("direction_id") or "").strip())].append(sid)
    assignment = {}
    for (rid, dir_id), sids in candidates.items():
        best = max(sids, key=lambda s: len(polylines[s]))
        assignment[f"{rid}_{dir_id}"] = {"shape_id": best, "orientation": "forward"}
    return assignment


def map_shapes_geometric(polylines, termini):
    """Score every shape against every route-direction terminus pair (forward and
    reversed endpoint distances), greedy global assignment cheapest-first,
    hard-reject over SHAPE_MATCH_MAX_M."""
    candidates = []
    for sid, coords in polylines.items():
        head, tail = coords[0], coords[-1]
        for t in termini:
            fwd = (haversine_m(head[0], head[1], t["first"][0], t["first"][1])
                   + haversine_m(tail[0], tail[1], t["last"][0], t["last"][1]))
            rev = (haversine_m(head[0], head[1], t["last"][0], t["last"][1])
                   + haversine_m(tail[0], tail[1], t["first"][0], t["first"][1]))
            if rev < fwd:
                candidates.append((rev, sid, t["key"], "reverse"))
            else:
                candidates.append((fwd, sid, t["key"], "forward"))
    candidates.sort(key=lambda c: c[0])
    assignment = {}
    used_shapes, used_keys = set(), set()
    for cost, sid, key, orientation in candidates:
        if cost > SHAPE_MATCH_MAX_M:
            break
        if sid in used_shapes or key in used_keys:
            continue
        assignment[key] = {"shape_id": sid, "orientation": orientation}
        used_shapes.add(sid)
        used_keys.add(key)
    return assignment


def build_route_shapes():
    print("\n=== route_shapes.json (road-following polylines) ===")
    polylines, shape_stats = load_shape_polylines()
    if polylines is None:
        print(f"SKIP: {shape_stats['error']}")
        return None
    print(f"shapes.txt: {shape_stats['shape_ids']} shape ids, {shape_stats['rows']} point rows, "
          f"{shape_stats['rejected_points']} rejected (bounds/malformed), "
          f"{shape_stats['dropped_short']} shapes dropped (<{SHAPE_MIN_POINTS} points), "
          f"{shape_stats['points_kept']} points kept")

    termini, termini_skipped = load_route_direction_termini()
    if termini is None:
        print(f"SKIP: committed routes.json/stages.json not found under {ASSET_DIR} - cannot map shapes")
        return None

    mode = "trips.txt (authoritative)"
    assignment = map_shapes_via_trips(polylines)
    if assignment is None:
        mode = "geometric endpoint matching (raw/trips.txt absent)"
        assignment = map_shapes_geometric(polylines, termini)

    termini_by_key = {t["key"]: t for t in termini}
    rows = []
    out = {}
    for key, info in assignment.items():
        coords = polylines[info["shape_id"]]
        final = list(reversed(coords)) if info["orientation"] == "reverse" else coords
        t = termini_by_key.get(key)
        err = ""
        if t is not None:
            err = round((haversine_m(final[0][0], final[0][1], t["first"][0], t["first"][1])
                         + haversine_m(final[-1][0], final[-1][1], t["last"][0], t["last"][1])) / 2)
        out[key] = [{"lat": round(lat, 6), "lng": round(lon, 6)} for lat, lon in final]
        rows.append({
            "key": key,
            "route_number": t["route_number"] if t else "",
            "headsign": t["headsign"] if t else "",
            "shape_id": info["shape_id"],
            "orientation": info["orientation"],
            "avg_endpoint_error_m": err,
            "status": "matched",
        })

    unmatched = [t["key"] for t in termini if t["key"] not in out]
    for k in unmatched:
        t = termini_by_key[k]
        rows.append({
            "key": k,
            "route_number": t["route_number"],
            "headsign": t["headsign"],
            "shape_id": "",
            "orientation": "",
            "avg_endpoint_error_m": "",
            "status": "unmatched",
        })
    used_shape_ids = {info["shape_id"] for info in assignment.values()}
    unused = sorted(set(polylines) - used_shape_ids)

    out_path = os.path.join(ASSET_DIR, "route_shapes.json")
    # compact JSON: 36k+ points, indent would triple the asset size
    with open(out_path, "w") as f:
        json.dump(out, f, separators=(",", ":"))

    report_path = os.path.join(OUT_DIR, "shapes_match_report.csv")
    with open(report_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=[
            "key", "route_number", "headsign", "shape_id", "orientation",
            "avg_endpoint_error_m", "status",
        ])
        writer.writeheader()
        for r in sorted(rows, key=lambda r: (r["status"] != "matched", r["key"])):
            writer.writerow(r)

    errors = sorted(r["avg_endpoint_error_m"] for r in rows
                    if r["status"] == "matched" and r["avg_endpoint_error_m"] != "")
    total_dirs = len(termini)
    matched = len(out)
    rate = (100.0 * matched / total_dirs) if total_dirs else 0.0

    def percentile(p):
        if not errors:
            return "n/a"
        idx = min(len(errors) - 1, int(round(p / 100 * (len(errors) - 1))))
        return f"{errors[idx]}m"

    print(f"mapping source: {mode}")
    print(f"route-directions: {total_dirs} candidates"
          + (f" ({termini_skipped} skipped: missing terminus coords)" if termini_skipped else ""))
    print(f"matched: {matched}/{total_dirs} ({rate:.1f}%)")
    if errors:
        print(f"avg endpoint error (both ends): median {percentile(50)}, "
              f"p90 {percentile(90)}, max {errors[-1]}m")
    if unmatched:
        shown = ", ".join(unmatched[:20])
        print(f"UNMATCHED route-directions ({len(unmatched)}): {shown}"
              + (" ..." if len(unmatched) > 20 else ""))
    if unused:
        shown = ", ".join(unused[:20])
        print(f"unused shape ids ({len(unused)}): {shown}"
              + (" ..." if len(unused) > 20 else ""))
    size_kb = os.path.getsize(out_path) / 1024
    print(f"wrote {matched} polylines ({size_kb:.0f} KB) -> {out_path}")
    print(f"per-pair detail -> {report_path}")
    return {"matched": matched, "total": total_dirs, "rate": rate, "mode": mode}


shapes_stats = build_route_shapes()

# ---------- legacy conversion needs the rest of the feed ----------

LEGACY_FEED = ("stops.txt", "routes.txt", "trips.txt", "stop_times.txt", "frequencies.txt")
missing_feed = [n for n in LEGACY_FEED if not os.path.exists(f"{DATA_DIR}/{n}")]
if missing_feed:
    print(f"\nraw feed incomplete, skipping legacy stages/routes conversion. "
          f"Missing from {DATA_DIR}: {', '.join(missing_feed)}")
    raise SystemExit(0)

# ---------- load stops.txt ----------

stops = []  # list of dicts: stop_id, name, lat, lon, location_type, parent_station
bad_rows = []
with open(f"{DATA_DIR}/stops.txt", encoding="utf-8-sig") as f:
    reader = csv.DictReader(f)
    for row in reader:
        try:
            lat = float(row['stop_lat'])
            lon = float(row['stop_lon'])
        except (ValueError, KeyError):
            bad_rows.append(row)
            continue
        # sanity bound check - rough Nairobi metro + extended commuter belt
        if not (-1.6 <= lat <= -1.0 and 36.5 <= lon <= 37.3):
            bad_rows.append(row)
            continue
        stops.append({
            'stop_id': row['stop_id'],
            'name': row['stop_name'].strip(),
            'lat': lat,
            'lon': lon,
            'location_type': row.get('location_type', '').strip(),
            'parent_station': row.get('parent_station', '').strip(),
        })

# ---------- load routes.txt, trips.txt, stop_times.txt, frequencies.txt ----------

routes = []
with open(f"{DATA_DIR}/routes.txt", encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        routes.append(row)

trips = []
with open(f"{DATA_DIR}/trips.txt", encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        trips.append(row)
trip_by_id = {t['trip_id']: t for t in trips}

stop_times_by_trip = defaultdict(list)
with open(f"{DATA_DIR}/stop_times.txt", encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        stop_times_by_trip[row['trip_id']].append(row)
for tid in stop_times_by_trip:
    stop_times_by_trip[tid].sort(key=lambda r: int(r['stop_sequence']))

freq_by_trip = defaultdict(list)
with open(f"{DATA_DIR}/frequencies.txt", encoding="utf-8-sig") as f:
    for row in csv.DictReader(f):
        freq_by_trip[row['trip_id']].append(row)

# ---------- dedup stops into canonical stages ----------
# group by normalized name, then union-find cluster within MERGE_RADIUS_M

MERGE_RADIUS_M = 250       # same-name stops within this distance = same physical stage
OUTLIER_FLAG_M = 1500      # same-name clusters farther than this = needs human review

by_name = defaultdict(list)
for s in stops:
    by_name[normalize_name(s['name'])].append(s)

canonical_stages = []   # final deduped stage list
stop_id_to_stage_id = {}  # map every original GTFS stop_id -> canonical stage_id
flagged_pairs = []       # for review CSV

for norm_name, group in by_name.items():
    n = len(group)
    parent = list(range(n))
    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb

    for i in range(n):
        for j in range(i+1, n):
            d = haversine_m(group[i]['lat'], group[i]['lon'], group[j]['lat'], group[j]['lon'])
            if d <= MERGE_RADIUS_M:
                union(i, j)

    clusters = defaultdict(list)
    for i in range(n):
        clusters[find(i)].append(group[i])

    cluster_list = list(clusters.values())

    # flag pairs of clusters (same name) that are far apart from each other
    if len(cluster_list) > 1:
        for ci in range(len(cluster_list)):
            for cj in range(ci+1, len(cluster_list)):
                lat_i = sum(s['lat'] for s in cluster_list[ci]) / len(cluster_list[ci])
                lon_i = sum(s['lon'] for s in cluster_list[ci]) / len(cluster_list[ci])
                lat_j = sum(s['lat'] for s in cluster_list[cj]) / len(cluster_list[cj])
                lon_j = sum(s['lon'] for s in cluster_list[cj]) / len(cluster_list[cj])
                d = haversine_m(lat_i, lon_i, lat_j, lon_j)
                if d >= OUTLIER_FLAG_M:
                    flagged_pairs.append({
                        'name': group[0]['name'],
                        'cluster_a_stop_ids': ';'.join(s['stop_id'] for s in cluster_list[ci]),
                        'cluster_a_lat': round(lat_i, 6),
                        'cluster_a_lon': round(lon_i, 6),
                        'cluster_b_stop_ids': ';'.join(s['stop_id'] for s in cluster_list[cj]),
                        'cluster_b_lat': round(lat_j, 6),
                        'cluster_b_lon': round(lon_j, 6),
                        'distance_m': round(d),
                    })

    for idx, cluster in enumerate(cluster_list):
        lat_c = sum(s['lat'] for s in cluster) / len(cluster)
        lon_c = sum(s['lon'] for s in cluster) / len(cluster)
        base_slug = slugify(cluster[0]['name'])
        stage_id = base_slug if len(cluster_list) == 1 else f"{base_slug}_{idx+1}"
        canonical_stages.append({
            'stage_id': stage_id,
            'stage_name': cluster[0]['name'],
            'latitude': round(lat_c, 6),
            'longitude': round(lon_c, 6),
            'member_stop_ids': [s['stop_id'] for s in cluster],
            'routes_served': set(),  # filled in below
        })
        for s in cluster:
            stop_id_to_stage_id[s['stop_id']] = stage_id

# ---------- build route_stops / ordered_stages per route+direction, attach routes_served ----------

route_meta = {r['route_id']: r for r in routes}
route_trip_sequences = defaultdict(list)  # route_id -> list of (direction_id, [stage_id,...])

for trip in trips:
    tid = trip['trip_id']
    rid = trip['route_id']
    sts = stop_times_by_trip.get(tid, [])
    stage_seq = []
    for st in sts:
        sid = stop_id_to_stage_id.get(st['stop_id'])
        if sid and (not stage_seq or stage_seq[-1] != sid):
            stage_seq.append(sid)
    if stage_seq:
        route_trip_sequences[rid].append({
            'trip_id': tid,
            'direction_id': trip.get('direction_id', ''),
            'headsign': trip.get('trip_headsign', ''),
            'ordered_stages': stage_seq,
        })
        for sid in stage_seq:
            # attach this route's short name to the stage's routes_served
            for s in canonical_stages:
                pass  # placeholder, done via index below

stage_index = {s['stage_id']: s for s in canonical_stages}
for rid, trip_list in route_trip_sequences.items():
    short_name = route_meta.get(rid, {}).get('route_short_name', rid)
    for t in trip_list:
        for sid in t['ordered_stages']:
            stage_index[sid]['routes_served'].add(short_name)

# ---------- frequency -> peak/offpeak headway per route ----------

def classify_band(start_time):
    try:
        hh = int(start_time.split(':')[0])
    except Exception:
        return 'offpeak'
    if 6 <= hh < 9 or 16 <= hh < 20:
        return 'peak'
    return 'offpeak'

route_headways = defaultdict(lambda: {'peak': [], 'offpeak': []})
for tid, entries in freq_by_trip.items():
    trip = trip_by_id.get(tid)
    if not trip:
        continue
    rid = trip['route_id']
    for e in entries:
        band = classify_band(e['start_time'])
        route_headways[rid][band].append(int(e['headway_secs']))

# ---------- assemble final route records ----------

final_routes = []
for rid, trip_list in route_trip_sequences.items():
    meta = route_meta.get(rid, {})
    # pick the longest trip per direction as representative
    by_dir = {}
    for t in trip_list:
        d = t['direction_id']
        if d not in by_dir or len(t['ordered_stages']) > len(by_dir[d]['ordered_stages']):
            by_dir[d] = t
    hw = route_headways.get(rid, {'peak': [], 'offpeak': []})
    peak_hw = sorted(hw['peak'])
    offpeak_hw = sorted(hw['offpeak'])
    final_routes.append({
        'route_id': rid,
        'route_number': meta.get('route_short_name', ''),
        'route_name': meta.get('route_long_name', ''),
        'directions': [
            {
                'direction_id': d,
                'headsign': t['headsign'],
                'ordered_stages': t['ordered_stages'],
                'stage_count': len(t['ordered_stages']),
            }
            for d, t in sorted(by_dir.items())
        ],
        'peak_headway_min_range': [round(min(peak_hw)/60,1), round(max(peak_hw)/60,1)] if peak_hw else None,
        'offpeak_headway_min_range': [round(min(offpeak_hw)/60,1), round(max(offpeak_hw)/60,1)] if offpeak_hw else None,
    })

# finalize stages (convert routes_served set -> sorted list, drop internal member list from main export
# but keep a separate trace file for auditing)
stages_export = []
for s in canonical_stages:
    stages_export.append({
        'stage_id': s['stage_id'],
        'stage_name': s['stage_name'],
        'latitude': s['latitude'],
        'longitude': s['longitude'],
        'routes_served': sorted(s['routes_served']),
    })

# ---------- write outputs ----------

with open(f"{OUT_DIR}/stages_clean.json", 'w') as f:
    json.dump(stages_export, f, indent=2)

with open(f"{OUT_DIR}/routes_clean.json", 'w') as f:
    json.dump(final_routes, f, indent=2)

with open(f"{OUT_DIR}/stages_trace.json", 'w') as f:
    json.dump(canonical_stages, f, indent=2, default=list)

with open(f"{OUT_DIR}/review_flagged.csv", 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=[
        'name','cluster_a_stop_ids','cluster_a_lat','cluster_a_lon',
        'cluster_b_stop_ids','cluster_b_lat','cluster_b_lon','distance_m'
    ])
    writer.writeheader()
    for row in sorted(flagged_pairs, key=lambda r: -r['distance_m']):
        writer.writerow(row)

with open(f"{OUT_DIR}/bad_rows.csv", 'w', newline='') as f:
    if bad_rows:
        writer = csv.DictWriter(f, fieldnames=list(bad_rows[0].keys()))
        writer.writeheader()
        for row in bad_rows:
            writer.writerow(row)

# ---------- report ----------

stages_with_0_routes = sum(1 for s in stages_export if not s['routes_served'])
stages_with_1_route = sum(1 for s in stages_export if len(s['routes_served']) == 1)
stages_with_many = sum(1 for s in stages_export if len(s['routes_served']) >= 5)

report = f"""# NaVi GTFS Import Report

## Input
- {len(stops)} valid stop rows parsed, {len(bad_rows)} rows rejected (bad coordinates / malformed) -> see bad_rows.csv
- {len(routes)} routes, {len(trips)} trips, {sum(len(v) for v in stop_times_by_trip.values())} stop_time rows

## Deduplication (merge radius {MERGE_RADIUS_M}m, outlier flag threshold {OUTLIER_FLAG_M}m)
- {len(stops)} raw GTFS stops -> **{len(canonical_stages)} canonical stages** after merging near-duplicates
- {len(flagged_pairs)} same-name-but-far-apart pairs flagged for human review -> see review_flagged.csv
  (these were NOT auto-merged; each is kept as a separate stage until a human confirms)

## Stage coverage
- {stages_with_0_routes} canonical stages ended up with 0 routes attached (likely stops with no valid stop_times reference - check these)
- {stages_with_1_route} stages served by exactly 1 route
- {stages_with_many} stages served by 5+ routes (likely major interchanges/termini)

## Routes
- {len(final_routes)} routes successfully assembled with ordered stage sequences
- Headway (frequency) data available for {sum(1 for r in final_routes if r['peak_headway_min_range'])} of {len(final_routes)} routes

## Output files
- stages_clean.json    - deduped stages, ready to map into StageRecord
- routes_clean.json    - routes with ordered_stages per direction + headway ranges
- stages_trace.json    - same as stages_clean but includes which original GTFS stop_ids were merged (audit trail)
- review_flagged.csv   - same-name stops that are suspiciously far apart (needs a human, likely your friends' corridor review)
- bad_rows.csv         - GTFS rows rejected during parsing (bad/missing coordinates)
"""

with open(f"{OUT_DIR}/import_report.md", 'w') as f:
    f.write(report)

print(report)
