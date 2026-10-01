enum JourneyPhase {
  beforeTravel,
  walkingToStage,
  waitingForMatatu,
  riding,
  approachingDestination,
  alighting,
  finalWalking,
  journeyComplete,
}

enum TimelineItemStatus { pending, current, completed }

class TimelineItem {
  final String id;
  final String label;
  final String? subtitle;
  final TimelineItemStatus status;
  final bool isWalking;
  final String? routeNumber;
  final String iconName;

  const TimelineItem({
    required this.id,
    required this.label,
    this.subtitle,
    required this.status,
    this.isWalking = false,
    this.routeNumber,
    this.iconName = 'location_on',
  });

  TimelineItem copyWith({TimelineItemStatus? status}) {
    return TimelineItem(
      id: id,
      label: label,
      subtitle: subtitle,
      status: status ?? this.status,
      isWalking: isWalking,
      routeNumber: routeNumber,
      iconName: iconName,
    );
  }
}

class AssistantMessage {
  final String text;
  final AssistantMessageType type;
  final DateTime timestamp;
  final int priority;

  AssistantMessage({
    required this.text,
    required this.type,
    DateTime? timestamp,
    this.priority = 0,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum AssistantMessageType {
  info,
  instruction,
  warning,
  alert,
  encouragement,
  arrival,
}

class StageInfo {
  final String name;
  final String? routeNumber;
  final double? distance;
  final int? stopNumber;

  const StageInfo({
    required this.name,
    this.routeNumber,
    this.distance,
    this.stopNumber,
  });
}

class JourneyNotification {
  final String title;
  final String body;
  final JourneyPhase phase;
  final int priority;

  const JourneyNotification({
    required this.title,
    required this.body,
    required this.phase,
    this.priority = 0,
  });
}

class RouteProgress {
  final int completedStops;
  final int totalStops;
  final double progressFraction;
  final Duration elapsed;
  final Duration estimatedRemaining;
  final DateTime estimatedArrival;

  const RouteProgress({
    this.completedStops = 0,
    this.totalStops = 0,
    this.progressFraction = 0.0,
    this.elapsed = Duration.zero,
    this.estimatedRemaining = Duration.zero,
    required this.estimatedArrival,
  });
}

class JourneyRouteSummary {
  final String routeNumber;
  final String routeName;
  final String fromStage;
  final String toStage;
  final double fare;
  final int estimatedMinutes;
  final int totalStops;

  const JourneyRouteSummary({
    required this.routeNumber,
    required this.routeName,
    required this.fromStage,
    required this.toStage,
    required this.fare,
    required this.estimatedMinutes,
    required this.totalStops,
  });
}

class SavedDestination {
  final String id;
  final String label;
  final String? stageId;
  final String? stageName;
  final double latitude;
  final double longitude;
  final SavedDestinationType type;

  const SavedDestination({
    required this.id,
    required this.label,
    this.stageId,
    this.stageName,
    required this.latitude,
    required this.longitude,
    required this.type,
  });
}

enum SavedDestinationType { home, campus, work, frequent }
