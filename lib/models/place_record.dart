/// A named landmark/area destination per the transport data spec §1.1.
///
/// Places are the human-readable layer on top of the stage network: an estate
/// ("Roysambu"), a landmark ("Two Rivers Mall") or an institution
/// ("Kenyatta National Hospital") the rider may not know by its bus-stop name.
/// Stages optionally link back to a place through `StageRecord.placeId`.
class PlaceRecord {
  /// Stable identifier following the spec §4 convention: `PL` + zero-padded
  /// 4-digit sequence. Assigned once, never reused.
  final String placeId;

  /// Primary display name.
  final String name;

  /// Secondary names riders may type ("TRM" for "Two Rivers Mall").
  final List<String> aliases;

  /// §1.1 category the place belongs to.
  final PlaceType type;

  final double latitude;
  final double longitude;

  /// §5 provenance of the record.
  final PlaceSource source;

  /// §6 what confidence we have in the record's identity/location.
  final PlaceConfidence confidence;

  const PlaceRecord({
    required this.placeId,
    required this.name,
    this.aliases = const [],
    required this.type,
    required this.latitude,
    required this.longitude,
    this.source = PlaceSource.contributor,
    this.confidence = PlaceConfidence.unverified,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'place_id': placeId,
      'name': name,
      'aliases': aliases,
      'type': type.name,
      'latitude': latitude,
      'longitude': longitude,
      'source': source.name,
      'confidence': confidence.name,
    };
    return map;
  }

  factory PlaceRecord.fromMap(Map<String, dynamic> map) {
    return PlaceRecord(
      placeId: map['place_id'] ?? map['id'] ?? '',
      name: map['name'] ?? '',
      aliases: List<String>.from(map['aliases'] ?? const []),
      type: _parseType(map['type']),
      latitude: (map['latitude'] ?? map['lat'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? map['lng'] ?? 0.0).toDouble(),
      source: _parseSource(map['source']),
      confidence: _parseConfidence(map['confidence']),
    );
  }

  static PlaceType _parseType(dynamic raw) {
    if (raw is PlaceType) return raw;
    if (raw is String) {
      for (final value in PlaceType.values) {
        if (value.name == raw) return value;
      }
    }
    return PlaceType.area;
  }

  static PlaceSource _parseSource(dynamic raw) {
    if (raw is PlaceSource) return raw;
    if (raw is String) {
      for (final value in PlaceSource.values) {
        if (value.name == raw) return value;
      }
    }
    return PlaceSource.contributor;
  }

  static PlaceConfidence _parseConfidence(dynamic raw) {
    if (raw is PlaceConfidence) return raw;
    if (raw is String) {
      for (final value in PlaceConfidence.values) {
        if (value.name == raw) return value;
      }
    }
    return PlaceConfidence.unverified;
  }

  @override
  String toString() => 'PlaceRecord($placeId: $name, $type)';
}

enum PlaceType { area, landmark, institution, building }

enum PlaceSource { gtfsImport, contributor, mapboxGeocode }

enum PlaceConfidence { verified, unverified, disputed }