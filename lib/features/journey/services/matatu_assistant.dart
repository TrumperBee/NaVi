import 'package:navi_app/features/journey/models/journey_models.dart';

class MatatuAssistant {
  String getMessageForPhase(
    JourneyPhase phase, {
    String routeNumber = '',
    String fromStage = '',
    String toStage = '',
    String destination = '',
    int remainingStops = 0,
    double fare = 0.0,
    int elapsedMinutes = 0,
  }) {
    switch (phase) {
      case JourneyPhase.walkingToStage:
        return 'Walk to $fromStage to board Route $routeNumber.';
      case JourneyPhase.waitingForMatatu:
        final fareStr = 'KES ${fare.toStringAsFixed(0)}';
        return 'Board Route $routeNumber at $fromStage. Current fare: $fareStr.';
      case JourneyPhase.riding:
        if (remainingStops <= 2 && remainingStops > 0) {
          return 'Prepare to alight in $remainingStops stop${remainingStops > 1 ? 's' : ''}.';
        }
        return 'En route on Route $routeNumber. $remainingStops stops remaining to $toStage.';
      case JourneyPhase.approachingDestination:
        return 'You are approaching $toStage. Prepare to alight.';
      case JourneyPhase.alighting:
        return 'Alight at $toStage. Walk ${_estimateWalkingDistance(destination, toStage)} to reach $destination.';
      case JourneyPhase.finalWalking:
        return 'Walking to $destination. You\'re almost there!';
      case JourneyPhase.journeyComplete:
        return 'You have arrived at $destination. Journey completed in ${elapsedMinutes} min.';
      case JourneyPhase.beforeTravel:
        return 'Where would you like to go?';
    }
  }

  String getRidingUpdate({
    String routeNumber = '',
    int remainingStops = 0,
    double progressFraction = 0.0,
  }) {
    if (remainingStops <= 2) {
      return 'Prepare to alight — $remainingStops stop${remainingStops > 1 ? 's' : ''} away.';
    }
    if (progressFraction > 0.75) {
      return 'Almost there! $remainingStops stops remaining.';
    }
    return 'Still en route on Route $routeNumber. $remainingStops stops to go.';
  }

  JourneyNotification? getNotificationForPhase(JourneyPhase phase) {
    switch (phase) {
      case JourneyPhase.walkingToStage:
        return const JourneyNotification(
          title: 'Walk to Stage',
          body: 'Proceed to the boarding stage to begin your journey.',
          phase: JourneyPhase.walkingToStage,
          priority: 1,
        );
      case JourneyPhase.waitingForMatatu:
        return const JourneyNotification(
          title: 'Ready to Board',
          body: 'Your matatu is available. Please board to continue.',
          phase: JourneyPhase.waitingForMatatu,
          priority: 2,
        );
      case JourneyPhase.approachingDestination:
        return const JourneyNotification(
          title: 'Prepare to Alight',
          body: 'You are approaching your destination. Get ready to alight.',
          phase: JourneyPhase.approachingDestination,
          priority: 3,
        );
      case JourneyPhase.alighting:
        return const JourneyNotification(
          title: 'Alight Now',
          body: 'You have reached your alighting point. Please alight.',
          phase: JourneyPhase.alighting,
          priority: 3,
        );
      case JourneyPhase.journeyComplete:
        return const JourneyNotification(
          title: 'Journey Complete',
          body: 'You have arrived at your destination.',
          phase: JourneyPhase.journeyComplete,
          priority: 1,
        );
      default:
        return null;
    }
  }

  String getStageTip(String stageName, {double fare = 0.0}) {
    if (fare > 0) {
      return 'Tip: Confirm fare before boarding at $stageName (approx KES ${fare.toStringAsFixed(0)}).';
    }
    return 'Tip: Confirm the route number with the conductor at $stageName.';
  }

  String getSafetyReminder(String stageName) {
    return 'Keep your belongings secure while at $stageName.';
  }

  String _estimateWalkingDistance(String destination, String stage) {
    return '200m';
  }
}
