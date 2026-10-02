"""
NaVi GTFS Import & Cleanup Script
Converts Digital Matatus GTFS feed (2019) into NaVi's places/stages/routes/route_stops
seed data, with deduplication of near-duplicate stop entries and an outlier review report.

Input:  the 6 relevant GTFS files (stops, routes, trips, stop_times, frequencies, shapes)
Output: 
  - stages_clean.json      (deduped canonical stages, ready for Dart seed import)
  - routes_clean.json      (routes with ordered stop sequences + fare/duration estimates)
  - review_flagged.csv     (same-name stops that are suspiciously far apart -> needs a human)
  - import_report.md       (summary stats for a human to sanity check before trusting this)
"""
import csv
import json
import math
import re
from collections import defaultdict

DATA_DIR = "/mnt/user-data/uploads"
OUT_DIR = "/home/claude/gtfs_import/out"
import os
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
