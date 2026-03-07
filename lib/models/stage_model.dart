class StageModel {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String corridor;
  final List<String>? routes;
  final String? area;

  StageModel({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.corridor,
    this.routes,
    this.area,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lng': lng,
      'corridor': corridor,
      'routes': routes,
      'area': area,
    };
  }

  factory StageModel.fromMap(Map<String, dynamic> map, String documentId) {
    return StageModel(
      id: documentId,
      name: map['name'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      corridor: map['corridor'] ?? '',
      routes: map['routes'] != null ? List<String>.from(map['routes']) : null,
      area: map['area'],
    );
  }
}