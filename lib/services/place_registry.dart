import 'package:navi_app/data/nairobi_places_seed.dart';
import 'package:navi_app/models/place_record.dart';
import 'package:navi_app/utils/string_match.dart';

/// In-memory source of the named-place universe for the synchronous local
/// search layer (`CorridorResolver`, `SearchViewModel`).
///
/// Defaults to the curated [nairobiPlaces] seed so unit tests and any code
/// path that runs before a sync/import behave as before. After the community
/// pipeline ships places, [setPlaces] swaps in the synced universe while
/// [nairobiPlaces] remains the fallback default — same pattern as
/// `StageRegistry`, so places never leave two competing sources live at once.
class PlaceRegistry {
  PlaceRegistry._();

  static List<PlaceRecord> _places = nairobiPlaces;

  /// Active place list.
  static List<PlaceRecord> get all => _places;

  /// Replaces the active place list. The swap is ignored when [places] is
  /// empty so a failed sync never wipes the seed.
  static void setPlaces(List<PlaceRecord> places) {
    if (places.isNotEmpty) {
      _places = List.unmodifiable(places);
    }
  }

  static PlaceRecord? findById(String placeId) {
    for (final place in _places) {
      if (place.placeId == placeId) return place;
    }
    return null;
  }

  /// Single best match for [query] against place name and aliases.
  /// Exact case-insensitive hits win, then containment, then fuzzy
  /// (Levenshtein within [kLevenshteinTolerance]). Returns null when nothing
  /// is close enough — callers fall through to the stage layer.
  static PlaceRecord? findByName(String query, {bool allowFuzzy = true}) {
    final matches = findMatching(query, allowFuzzy: allowFuzzy);
    return matches.isEmpty ? null : matches.first;
  }

  static PlaceRecord? findExact(String query) {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return null;
    for (final place in _places) {
      if (_allNames(place).contains(lowerQuery)) return place;
    }
    return null;
  }

  /// All places whose name or alias matches [query], best match first. When
  /// both an area and a landmark match (e.g. "Githurai" and "Githurai 44")
  /// both are returned so the caller can present the alternatives.
  static List<PlaceRecord> findMatching(String query, {bool allowFuzzy = true}) {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return [];

    final scored = <_ScoredPlace>[];
    for (final place in _places) {
      final score = _matchScore(place, lowerQuery, allowFuzzy);
      if (score > 0) {
        scored.add(_ScoredPlace(place, score));
      }
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.place.placeId.compareTo(b.place.placeId);
    });

    return scored.map((s) => s.place).toList();
  }

  static Set<String> _allNames(PlaceRecord place) {
    return {place.name.toLowerCase(), ...place.aliases.map((a) => a.toLowerCase())};
  }

  static double _matchScore(PlaceRecord place, String lowerQuery, bool allowFuzzy) {
    double best = 0;
    for (final name in _allNames(place)) {
      double score = 0;
      if (name == lowerQuery) {
        score = 1.0;
      } else if (name.contains(lowerQuery) || lowerQuery.contains(name)) {
        score = 0.9;
      } else if (allowFuzzy &&
          levenshteinDistance(name, lowerQuery) <= kLevenshteinTolerance) {
        score = 0.7;
      }
      if (score > best) best = score;
    }
    return best;
  }
}

class _ScoredPlace {
  final PlaceRecord place;
  final double score;
  _ScoredPlace(this.place, this.score);
}