library;

import 'dart:math';

/// Shared named-entity matching primitives for the local search layers
/// (`CorridorResolver`, `PlaceRegistry`). Extracted so places and stages agree
/// on what counts as a fuzzy match instead of drifting into two slightly
/// different tolerances over time.

/// Answer to "how different may a name be and still be the same entity?" —
/// two edits or fewer (shared with `CorridorResolver`'s stage lookup).
const int kLevenshteinTolerance = 2;

/// Fraction of a name's characters that must align in the score-based fallback.
const double kFuzzyMatchThreshold = 0.85;

/// Levenshtein edit distance between [s1] and [s2]. Deterministic, allocation
/// bounded by the shorter string's length; safe for the small lookup
/// universes (hundreds of stages, tens of places) it is used against.
int levenshteinDistance(String s1, String s2) {
  if (s1 == s2) return 0;
  if (s1.isEmpty) return s2.length;
  if (s2.isEmpty) return s1.length;

  final len1 = s1.length;
  final len2 = s2.length;
  final dp = List.generate(len1 + 1, (_) => List<int>.filled(len2 + 1, 0));

  for (int i = 0; i <= len1; i++) {
    dp[i][0] = i;
  }
  for (int j = 0; j <= len2; j++) {
    dp[0][j] = j;
  }

  for (int i = 1; i <= len1; i++) {
    for (int j = 1; j <= len2; j++) {
      final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
      dp[i][j] = min(
        dp[i - 1][j] + 1,
        min(dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost),
      );
    }
  }
  return dp[len1][len2];
}