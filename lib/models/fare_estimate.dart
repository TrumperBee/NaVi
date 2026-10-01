enum FareTier { short, medium, long }

enum TimeOfDay { offPeak, peak }

class FareEstimate {
  final int amountKsh;
  final FareTier tier;
  final TimeOfDay timeOfDay;
  final bool isWalking;

  const FareEstimate({
    required this.amountKsh,
    required this.tier,
    required this.timeOfDay,
    required this.isWalking,
  });

  factory FareEstimate.walking({required TimeOfDay timeOfDay}) {
    return FareEstimate(
      amountKsh: 0,
      tier: FareTier.short,
      timeOfDay: timeOfDay,
      isWalking: true,
    );
  }

  factory FareEstimate.matatu({
    required int amountKsh,
    required FareTier tier,
    required TimeOfDay timeOfDay,
  }) {
    return FareEstimate(
      amountKsh: amountKsh,
      tier: tier,
      timeOfDay: timeOfDay,
      isWalking: false,
    );
  }

  String get formattedAmount => 'KSh $amountKsh';

  @override
  String toString() {
    return 'FareEstimate(amountKsh: $amountKsh, tier: $tier, timeOfDay: $timeOfDay, isWalking: $isWalking)';
  }
}