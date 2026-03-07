class RouteModel {
  final String id;
  final String number;
  final String name;
  final String corridor;
  final List<String> majorStops;
  final String sacco;
  final String? description;

  RouteModel({
    required this.id,
    required this.number,
    required this.name,
    required this.corridor,
    required this.majorStops,
    required this.sacco,
    this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
      'name': name,
      'corridor': corridor,
      'major_stops': majorStops,
      'sacco': sacco,
      'description': description,
    };
  }

  factory RouteModel.fromMap(Map<String, dynamic> map, String documentId) {
    return RouteModel(
      id: documentId,
      number: map['number'] ?? '',
      name: map['name'] ?? '',
      corridor: map['corridor'] ?? '',
      majorStops: List<String>.from(map['major_stops'] ?? []),
      sacco: map['sacco'] ?? '',
      description: map['description'],
    );
  }

  @override
  String toString() {
    return '$number - $name ($sacco)';
  }
}