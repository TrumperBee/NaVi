import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../features/journey/models/journey_models.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../services/database/local_storage_service.dart';
import '../viewmodels/search_viewmodel.dart';
import '../design/navi_colors.dart';

/// Shared "Add / edit saved destination" dialog used by both the home screen
/// QuickGoRow and the map screen FavoritesBar. One implementation, one Mapbox
/// search path — the duplicate Nominatim dialogs are gone.
///
/// The dialog reuses the exact [SearchViewModel] used by the main search
/// overlay, so the "add a saved place" picker resolves the same real Nairobi
/// places. A "Use current location" row captures the user's position and asks
/// for a readable label (reverse-geocoded) before saving, per the ROLE.
class SavedDestinationDialog extends StatefulWidget {
  final SavedDestinationType type;

  const SavedDestinationDialog({super.key, required this.type});

  @override
  State<SavedDestinationDialog> createState() => _SavedDestinationDialogState();
}

class _SavedDestinationDialogState extends State<SavedDestinationDialog> {
  final TextEditingController _searchController = TextEditingController();
  late final SearchViewModel _viewModel = SearchViewModel();
  final LocationService _locationService = LocationService();
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _viewModel.updateQuery(_searchController.text);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final position = await _locationService.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      final geocoder = _viewModel.geocodingService;
      final reverse = await geocoder.geocodeReverse(point);

      if (!mounted) return;
      setState(() => _locating = false);

      final suggestedLabel = reverse?.placeName.isNotEmpty == true
          ? _primaryLabel(reverse!.placeName)
          : widget.type.label;
      await _confirmAndSave(suggestedLabel, point);
    } catch (_) {
      if (!mounted) return;
      setState(() => _locating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read your current location.'),
        ),
      );
    }
  }

  String _primaryLabel(String placeName) {
    final comma = placeName.indexOf(',');
    return comma > 0 ? placeName.substring(0, comma).trim() : placeName.trim();
  }

  Future<void> _confirmAndSave(String label, LatLng point) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Save as ${widget.type.label}?'),
        content: Text(
          '${widget.type.label} will route to\n\n$label\n'
          '(${point.latitude.toStringAsFixed(5)}, '
          '${point.longitude.toStringAsFixed(5)})',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _savePlace(label, point);
  }

  void _savePlace(String label, LatLng point) {
    final settings = context.read<SettingsService>();
    final kind = _placedKind(widget.type);
    if (kind != null) {
      settings.setSavedPlace(
        kind,
        SavedPlace(lat: point.latitude, lng: point.longitude, label: label),
      );
    } else {
      // Frequent destinations have no dedicated navi.places key — keep the
      // legacy Hive fav_frequent_* slot they have always used.
      final storage = LocalStorageService();
      final key = widget.type.name;
      storage.setSetting('fav_${key}_lat', point.latitude);
      storage.setSetting('fav_${key}_lng', point.longitude);
      storage.setStringSetting('fav_${key}_name', label);
    }
    Navigator.of(context).pop(true);
  }

  SavedPlaceKind? _placedKind(SavedDestinationType type) {
    switch (type) {
      case SavedDestinationType.home:
        return SavedPlaceKind.home;
      case SavedDestinationType.work:
        return SavedPlaceKind.work;
      case SavedDestinationType.campus:
        return SavedPlaceKind.campus;
      case SavedDestinationType.frequent:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(_title),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search for a ${widget.type.label} location...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              leading: _locating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.my_location, color: _color),
              title: const Text('Use current location'),
              subtitle: const Text('Set to where you are right now'),
              onTap: _locating ? null : _useCurrentLocation,
            ),
            const Divider(height: 1),
            Expanded(
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  if (_viewModel.isLoading && _viewModel.results.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_viewModel.results.isEmpty) {
                    return Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Type to search for a location'
                            : (_viewModel.error ?? 'No results found'),
                        style: TextStyle(
                          color: NaviColors.textSecondary(
                            Theme.of(context).brightness == Brightness.dark,
                          ),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: _viewModel.results.length,
                    itemBuilder: (ctx, i) {
                      final r = _viewModel.results[i];
                      return ListTile(
                        leading: Icon(_icon, color: _color),
                        title: Text(r.resolvedLabel),
                        subtitle:
                            r.secondaryLine != null &&
                                r.secondaryLine!.isNotEmpty
                            ? Text(
                                r.secondaryLine!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () {
                          _savePlace(
                            r.resolvedLabel,
                            LatLng(r.lat, r.lng),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  String get _title {
    switch (widget.type) {
      case SavedDestinationType.home:
        return 'Set Home Location';
      case SavedDestinationType.work:
        return 'Set Work Location';
      case SavedDestinationType.campus:
        return 'Set Campus Location';
      case SavedDestinationType.frequent:
        return 'Set Location';
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case SavedDestinationType.home:
        return Icons.home;
      case SavedDestinationType.work:
        return Icons.work;
      case SavedDestinationType.campus:
        return Icons.school;
      case SavedDestinationType.frequent:
        return Icons.star;
    }
  }

  Color get _color {
    switch (widget.type) {
      case SavedDestinationType.home:
        return Colors.blue;
      case SavedDestinationType.work:
        return Colors.orange;
      case SavedDestinationType.campus:
        return Colors.purple;
      case SavedDestinationType.frequent:
        return Colors.amber;
    }
  }
}

extension on SavedDestinationType {
  String get label {
    switch (this) {
      case SavedDestinationType.home:
        return 'Home';
      case SavedDestinationType.work:
        return 'Work';
      case SavedDestinationType.campus:
        return 'Campus';
      case SavedDestinationType.frequent:
        return 'Location';
    }
  }
}