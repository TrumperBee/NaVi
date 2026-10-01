import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart';
import '../models/transport_models.dart';
import '../data/seed_data.dart';

class PathfindingService {
  static final PathfindingService _instance = PathfindingService._internal();
  factory PathfindingService() => _instance;
  PathfindingService._internal();

  // Graph structure
  Map<String, Node> _nodes = {};
  Map<String, List<Edge>> _adjacencyList = {};
  final Set<String> _walkEdgeNodes = {};
  
  // Initialize the graph with stages and routes
  void initializeGraph(List<StageModel> stages, List<dynamic> routes) {
    _nodes.clear();
    _adjacencyList.clear();
    
    // Add all stages as nodes
    for (var stage in stages) {
      _nodes[stage.id] = stage;
      _adjacencyList[stage.id] = [];
    }
    
    // Build edges based on routes
    _buildEdgesFromRoutes(stages, routes);
  }
  
  // Build edges connecting stages that share routes
  void _buildEdgesFromRoutes(List<StageModel> stages, List<dynamic> routes) {
    // Group stages by route number
    Map<String, List<StageModel>> stagesByRoute = {};
    
    for (var stage in stages) {
      for (var routeNum in stage.routes) {
        stagesByRoute.putIfAbsent(routeNum, () => []).add(stage);
      }
    }
    
    // Create edges between stages on the same route
    for (var entry in stagesByRoute.entries) {
      final routeNum = entry.key;
      final routeStages = entry.value;
      
      for (int i = 0; i < routeStages.length; i++) {
        for (int j = i + 1; j < routeStages.length; j++) {
          final stageA = routeStages[i];
          final stageB = routeStages[j];
          final distance = _calculateHaversineDistance(
            LatLng(stageA.lat, stageA.lng),
            LatLng(stageB.lat, stageB.lng),
          );
          if (distance < 30000) {
            final travelTime = _estimateTravelTime(distance, 'medium');
            final baseFare = _estimateFare(distance);
            final edgeId = '${stageA.id}_${stageB.id}_$routeNum';
            _adjacencyList[stageA.id]!.add(Edge(
              id: edgeId,
              from: stageA,
              to: stageB,
              distance: distance,
              routeNumbers: [routeNum],
              averageTime: travelTime,
              baseFare: baseFare,
              trafficLevel: 'medium',
              lastUpdated: DateTime.now(),
            ));
            _adjacencyList[stageB.id]!.add(Edge(
              id: '${stageB.id}_${stageA.id}_$routeNum',
              from: stageB,
              to: stageA,
              distance: distance,
              routeNumbers: [routeNum],
              averageTime: travelTime,
              baseFare: baseFare,
              trafficLevel: 'medium',
              lastUpdated: DateTime.now(),
            ));
          }
        }
      }
    }
    
    // Add transfer edges between physically close stages (different routes)
    // so the graph is connected even if routes don't share a common stage
    for (int i = 0; i < stages.length; i++) {
      for (int j = i + 1; j < stages.length; j++) {
        final stageA = stages[i];
        final stageB = stages[j];
        // Check if they already share a route (already connected)
        final shareRoute = stageA.routes.any((r) => stageB.routes.contains(r));
        if (shareRoute) continue; // already connected via route edges
        final distance = _calculateHaversineDistance(
          LatLng(stageA.lat, stageA.lng),
          LatLng(stageB.lat, stageB.lng),
        );
        // Connect stages within 2km walking distance as transfer hubs
        if (distance < 2000) {
          final walkTime = (distance / 1.4).round();
          _adjacencyList[stageA.id]!.add(Edge(
            id: 'transfer_${stageA.id}_${stageB.id}',
            from: stageA,
            to: stageB,
            distance: distance,
            routeNumbers: ['walk'],
            averageTime: walkTime,
            baseFare: 0,
            trafficLevel: 'low',
            lastUpdated: DateTime.now(),
          ));
          _adjacencyList[stageB.id]!.add(Edge(
            id: 'transfer_${stageB.id}_${stageA.id}',
            from: stageB,
            to: stageA,
            distance: distance,
            routeNumbers: ['walk'],
            averageTime: walkTime,
            baseFare: 0,
            trafficLevel: 'low',
            lastUpdated: DateTime.now(),
          ));
        }
      }
    }
  }
  
  // Calculate Haversine distance between two LatLng points
  double _calculateHaversineDistance(LatLng point1, LatLng point2) {
    const double R = 6371000; // Earth's radius in meters
    double lat1 = point1.latitude * pi / 180;
    double lat2 = point2.latitude * pi / 180;
    double deltaLat = (point2.latitude - point1.latitude) * pi / 180;
    double deltaLng = (point2.longitude - point1.longitude) * pi / 180;

    double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
               cos(lat1) * cos(lat2) *
               sin(deltaLng / 2) * sin(deltaLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }
  
  // Estimate travel time based on distance and traffic
  int _estimateTravelTime(double distanceMeters, String trafficLevel) {
    // Average matatu speed: 30 km/h = 8.33 m/s
    double speed = 8.33;
    
    switch (trafficLevel) {
      case 'high':
        speed = 4.0; // 14.4 km/h
        break;
      case 'medium':
        speed = 6.0; // 21.6 km/h
        break;
      case 'low':
        speed = 8.33; // 30 km/h
        break;
    }
    
    return (distanceMeters / speed).round();
  }
  
  // Estimate fare based on distance
  double _estimateFare(double distanceMeters) {
    // Nairobi matatu fare structure: base 50 KSh + 10 KSh per km
    double distanceKm = distanceMeters / 1000;
    return 50.0 + (distanceKm * 10.0);
  }
  
  // Find nearest node to a given location
  Node? findNearestNode(LatLng location, {String? type}) {
    Node? nearest;
    double minDistance = double.infinity;
    
    for (var node in _nodes.values) {
      if (type != null && node.type != type) continue;
      
      double distance = _calculateHaversineDistance(
        location, 
        LatLng(node.lat, node.lng)
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = node;
      }
    }
    
    return nearest;
  }
  
  // Dijkstra's algorithm to find shortest path
  List<PathOption> findBestRoutes(LatLng start, LatLng end) {
    // Find nearest start and end nodes
    final startNode = findNearestNode(start);
    final endNode = findNearestNode(end);
    
    print('[ROUTE] findBestRoutes start=$start end=$end');
    print('[ROUTE] startNode=${startNode?.name}(${startNode?.id}) endNode=${endNode?.name}(${endNode?.id})');
    
    if (startNode == null || endNode == null) {
      print('[ROUTE] FAIL: startNode or endNode is null');
      return [];
    }
    
    // Add walking edges from user to start node
    _addWalkingEdge(startNode, start, 'walk_start');
    
    // Add walking edges from end node to destination
    _addWalkingEdge(endNode, end, 'walk_end');
    
    // Run Dijkstra for different priorities
    final timePaths = _dijkstra(startNode.id, endNode.id, priority: 'time');
    final costPaths = _dijkstra(startNode.id, endNode.id, priority: 'cost');
    final transferPaths = _dijkstra(startNode.id, endNode.id, priority: 'transfers');
    
    print('[ROUTE] time paths: ${timePaths.length}, cost paths: ${costPaths.length}, transfer paths: ${transferPaths.length}');
    
    // Remove temporary walking edges
    _removeWalkingEdge('walk_start');
    _removeWalkingEdge('walk_end');
    
    // Combine and deduplicate results
    List<PathOption> results = [];
    
    if (timePaths.isNotEmpty) {
      print('[ROUTE] Best time: ${timePaths.first.description} distance=${timePaths.first.totalDistance}m time=${timePaths.first.totalTime}s fare=${timePaths.first.totalFare}');
      results.add(timePaths.first);
    }
    if (costPaths.isNotEmpty) {
      bool exists = results.any((p) => 
        p.description == costPaths.first.description &&
        (p.totalTime - costPaths.first.totalTime).abs() < 60
      );
      if (!exists) {
        print('[ROUTE] Best cost: ${costPaths.first.description} distance=${costPaths.first.totalDistance}m time=${costPaths.first.totalTime}s fare=${costPaths.first.totalFare}');
        results.add(costPaths.first);
      }
    }
    if (transferPaths.isNotEmpty) {
      bool exists = results.any((p) => 
        p.description == transferPaths.first.description &&
        p.transferCount == transferPaths.first.transferCount
      );
      if (!exists) {
        print('[ROUTE] Best transfers: ${transferPaths.first.description} distance=${transferPaths.first.totalDistance}m time=${transferPaths.first.totalTime}s fare=${transferPaths.first.totalFare}');
        results.add(transferPaths.first);
      }
    }
    
    print('[ROUTE] Final unique options: ${results.length}');
    return results.take(3).toList();
  }
  
  // Add temporary walking edge (bidirectional)
  void _addWalkingEdge(Node node, LatLng point, String prefix) {
    final distance = _calculateHaversineDistance(
      point,
      LatLng(node.lat, node.lng)
    );
    final walkTime = (distance / 1.4).round(); // 1.4 m/s walking speed
    
    final tempNode = Node(
      id: prefix,
      name: 'Your Location',
      lat: point.latitude,
      lng: point.longitude,
      type: 'temporary',
    );
    
    // Forward edge: temp -> stage
    final walkEdge = Edge(
      id: '${prefix}_${node.id}',
      from: tempNode,
      to: node,
      distance: distance,
      routeNumbers: ['walk'],
      averageTime: walkTime,
      baseFare: 0,
      trafficLevel: 'low',
      lastUpdated: DateTime.now(),
    );
    _adjacencyList.putIfAbsent(prefix, () => []).add(walkEdge);
    
    // Reverse edge: stage -> temp (so Dijkstra starting from stage can reach walk_start)
    final reverseEdge = Edge(
      id: '${prefix}_${node.id}_rev',
      from: node,
      to: tempNode,
      distance: distance,
      routeNumbers: ['walk'],
      averageTime: walkTime,
      baseFare: 0,
      trafficLevel: 'low',
      lastUpdated: DateTime.now(),
    );
    _adjacencyList.putIfAbsent(node.id, () => []).add(reverseEdge);
    _walkEdgeNodes.add(node.id);
  }
  
  // Remove temporary walking edge
  void _removeWalkingEdge(String prefix) {
    _adjacencyList.remove(prefix);
    for (var nodeId in _walkEdgeNodes) {
      if (_adjacencyList.containsKey(nodeId)) {
        _adjacencyList[nodeId]!.removeWhere(
          (edge) => edge.id.endsWith('_rev') && edge.id.startsWith(prefix),
        );
      }
    }
    _walkEdgeNodes.clear();
  }
  
  // Dijkstra implementation with different priorities
  List<PathOption> _dijkstra(String startId, String endId, {required String priority}) {
    if (!_adjacencyList.containsKey(startId) || !_adjacencyList.containsKey(endId)) {
      return [];
    }
    
    // Priority queue based on current priority
    final queue = PriorityQueue<_DijkstraNode>(
      (a, b) => a.cost.compareTo(b.cost),
    );
    
    // Distance and path maps
    Map<String, double> dist = {};
    Map<String, _DijkstraNode> prev = {};
    Set<String> visited = {};
    
    // Initialize
    for (var nodeId in _adjacencyList.keys) {
      dist[nodeId] = double.infinity;
    }
    dist[startId] = 0;
    
    queue.add(_DijkstraNode(startId, 0, 0, 0, []));
    
    List<PathOption> results = [];
    
    while (queue.isNotEmpty && results.length < 3) {
      final current = queue.removeFirst();
      
      if (visited.contains(current.id)) continue;
      visited.add(current.id);
      
      if (current.id == endId) {
        // Reconstruct path
        final path = _reconstructPath(current);
        if (path != null) {
          results.add(path);
        }
        continue;
      }
      
      // Explore neighbors
      for (var edge in _adjacencyList[current.id] ?? []) {
        if (visited.contains(edge.to.id)) continue;
        
        double newCost;
        double newTime = current.time + edge.currentTime;
        double newFare = current.fare + edge.currentFare;
        int newTransfers = current.transfers;
        
        // Check if this edge requires a route transfer
        if (current.lastRoute != null && 
            !edge.routeNumbers.contains(current.lastRoute)) {
          newTransfers++;
        }
        
        // Calculate cost based on priority
        switch (priority) {
          case 'time':
            newCost = newTime;
            break;
          case 'cost':
            newCost = newFare;
            break;
          case 'transfers':
            newCost = newTransfers * 1000.0 + newTime / 60; // Weight transfers heavily
            break;
          default:
            newCost = newTime;
        }
        
        if (newCost < (dist[edge.to.id] ?? double.infinity)) {
          dist[edge.to.id] = newCost;
          
          final newNode = _DijkstraNode(
            edge.to.id,
            newCost,
            newTime,
            newFare,
            [...current.path, edge],
            lastRoute: edge.routeNumbers.isNotEmpty ? edge.routeNumbers.first : current.lastRoute,
            transfers: newTransfers,
          );
          
          queue.add(newNode);
          prev[edge.to.id] = newNode;
        }
      }
    }
    
    return results;
  }
  
  // Reconstruct path from Dijkstra result
  PathOption? _reconstructPath(_DijkstraNode node) {
    if (node.path.isEmpty) return null;
    
    final pathNodes = <Node>[];
    final edges = <Edge>[];
    final routeNumbers = <String>{};
    
    // Build path from edges
    for (var edge in node.path) {
      if (!pathNodes.contains(edge.from)) {
        pathNodes.add(edge.from);
      }
      pathNodes.add(edge.to);
      edges.add(edge);
      routeNumbers.addAll(edge.routeNumbers);
    }
    
    // Create description
    String description = _buildDescription(edges);
    
    return PathOption(
      path: pathNodes,
      edges: edges,
      totalDistance: edges.fold(0.0, (sum, e) => sum + e.distance),
      totalTime: node.time.round(),
      totalFare: node.fare,
      transferCount: node.transfers,
      routeNumbers: routeNumbers.toList(),
      description: description,
    );
  }
  
  // Build human-readable description
  String _buildDescription(List<Edge> edges) {
    if (edges.isEmpty) return 'No route found';
    
    List<String> parts = [];
    String? currentRoute;
    
    for (var edge in edges) {
      if (edge.routeNumbers.contains('walk')) {
        parts.add('Walk to ${edge.to.name}');
      } else {
        final route = edge.routeNumbers.first;
        if (currentRoute != route) {
          if (currentRoute != null) {
            parts.add('Transfer to Route $route');
          } else {
            parts.add('Board Route $route');
          }
          currentRoute = route;
        }
      }
    }
    
    parts.add('Arrive at destination');
    return parts.join(' → ');
  }
}

// Helper class for Dijkstra
class _DijkstraNode {
  final String id;
  final double cost;
  final double time;
  final double fare;
  final List<Edge> path;
  final String? lastRoute;
  final int transfers;
  
  _DijkstraNode(
    this.id,
    this.cost,
    this.time,
    this.fare,
    this.path, {
    this.lastRoute,
    this.transfers = 0,
  });
}
