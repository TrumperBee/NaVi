import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/data/seed_data.dart';

class RouteMatchingEngine {
  List<RouteModel> findRoutesBetweenStages(
    StageModel from,
    StageModel to,
  ) {
    final routes = SeedData.getRoutes();
    final fromRouteNumbers = from.routes;
    final toRouteNumbers = to.routes;

    final commonRoutes = fromRouteNumbers
        .where((r) => toRouteNumbers.contains(r))
        .toSet()
        .toList();

    return routes.where((route) =>
        commonRoutes.contains(route.number)
    ).toList();
  }

  List<RouteModel> findRoutesForStage(StageModel stage) {
    return SeedData.getRoutesForStage(stage.id);
  }

  List<RouteModel> findRoutesByCorridor(String corridor) {
    return SeedData.getRoutesByCorridor(corridor);
  }

  List<RouteModel> searchRoutes(String query) {
    final lowerQuery = query.toLowerCase();
    return SeedData.getRoutes().where((route) {
      return route.number.toLowerCase().contains(lowerQuery) ||
          route.name.toLowerCase().contains(lowerQuery) ||
          route.corridor.toLowerCase().contains(lowerQuery) ||
          route.sacco.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  bool doRoutesConnect(RouteModel route, StageModel stage) {
    return stage.routes.contains(route.number);
  }

  List<RouteModel> findRoutesByDestination(String destination) {
    return SeedData.findRoutesByDestination(destination);
  }
}
