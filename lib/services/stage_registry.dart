import 'package:navi_app/data/nairobi_stages_seed.dart';

/// In-memory source of the stop universe for the synchronous stage lookups
/// (`CorridorResolver`, `RouteBuilderService`).
///
/// Defaults to the curated [nairobiStages] seed so unit tests and any code
/// path that runs before the GTFS import behave exactly as before. After the
/// one-time GTFS bundle import, [setStages] swaps in the full stop universe
/// (2,771 unique stages), making search and route building treat the real GTFS
/// data as the primary source while [nairobiStages] remains the fallback
/// default — staging never leaves two competing sources live at once.
class StageRegistry {
  StageRegistry._();

  static List<StageData> _stages = nairobiStages;

  /// Active stage list. Uses the imported GTFS universe once it is loaded,
  /// otherwise the curated seed.
  static List<StageData> get all => _stages;

  /// Replaces the active stage list (e.g. after the GTFS import). The swap is
  /// ignored when [stages] is empty so a failed import never wipes the seed.
  static void setStages(List<StageData> stages) {
    if (stages.isNotEmpty) {
      _stages = List.unmodifiable(stages);
    }
  }
}