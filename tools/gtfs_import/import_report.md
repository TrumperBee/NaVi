# NaVi GTFS Import Report

## Input
- 4284 valid stop rows parsed, 0 rows rejected (bad coordinates / malformed) -> see bad_rows.csv
- 136 routes, 272 trips, 7533 stop_time rows

## Deduplication (merge radius 250m, outlier flag threshold 1500m)
- 4284 raw GTFS stops -> **2773 canonical stages** after merging near-duplicates
- 603 same-name-but-far-apart pairs flagged for human review -> see review_flagged.csv
  (these were NOT auto-merged; each is kept as a separate stage until a human confirms)

## Stage coverage
- 3 canonical stages ended up with 0 routes attached (likely stops with no valid stop_times reference - check these)
- 1572 stages served by exactly 1 route
- 257 stages served by 5+ routes (likely major interchanges/termini)

## Routes
- 136 routes successfully assembled with ordered stage sequences
- Headway (frequency) data available for 132 of 136 routes

## Output files
- stages_clean.json    - deduped stages, ready to map into StageRecord
- routes_clean.json    - routes with ordered_stages per direction + headway ranges
- stages_trace.json    - same as stages_clean but includes which original GTFS stop_ids were merged (audit trail)
- review_flagged.csv   - same-name stops that are suspiciously far apart (needs a human, likely your friends' corridor review)
- bad_rows.csv         - GTFS rows rejected during parsing (bad/missing coordinates)
