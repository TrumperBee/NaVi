import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;

import '../models/search_result.dart';
import '../viewmodels/search_viewmodel.dart';
import '../core/constants.dart';
import '../design/navi_colors.dart';
import '../utils/distance_formatter.dart';
import '../services/distance_calculator.dart';

class SearchOverlay extends StatefulWidget {
  final bool isTransportMode;
  final Function(String, LatLng) onSelectDestination;
  final VoidCallback onClose;

  /// Current user position, used to show "distance from you" per result.
  final LatLng? userPosition;

  const SearchOverlay({
    super.key,
    required this.isTransportMode,
    required this.onSelectDestination,
    required this.onClose,
    this.userPosition,
  });

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    context.read<SearchViewModel>().updateQuery(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SearchViewModel>(
      builder: (context, viewModel, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Positioned(
          top: 120,
          left: 16,
          right: 16,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            decoration: BoxDecoration(
              color: NaviColors.surface(isDark),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: NaviColors.dividerC(isDark))),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: 'Search for a place, stage, or address...',
                                prefixIcon: const Icon(Icons.search),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: widget.onClose,
                          ),
                        ],
                      ),
                      if (viewModel.searchSource != null && viewModel.searchSource!.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Row(
                              children: [
                                if (viewModel.isLoading)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                else
                                  Icon(
                                    _getSourceIcon(viewModel.searchSource!),
                                    size: 12,
                                    color: NaviColors.textSecondary(isDark),
                                  ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    viewModel.searchSource!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            NaviColors.textSecondary(isDark)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: viewModel.isLoading && viewModel.results.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : viewModel.results.isEmpty && _searchController.text.isNotEmpty
                          ? _buildEmptyState(viewModel, isDark)
                          : ListView.builder(
                              itemCount: viewModel.results.length,
                              itemBuilder: (context, index) {
                                final result = viewModel.results[index];
                                final distanceToUser = widget.userPosition == null
                                    ? null
                                    : DistanceCalculator.distanceMeters(
                                        widget.userPosition!,
                                        LatLng(result.lat, result.lng),
                                      );
                                return _SearchResultTile(
                                  result: result,
                                  distanceToUserMeters: distanceToUser,
                                  onTap: () => widget.onSelectDestination(
                                    result.resolvedLabel,
                                    LatLng(result.lat, result.lng),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(SearchViewModel viewModel, bool isDark) {
    final title = viewModel.error ?? 'No results found';
    final showFallbackNote = viewModel.error?.contains('local stage') == true ||
        viewModel.error?.contains('network') == true ||
        viewModel.searchSource?.contains('local stage') == true;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 48, color: NaviColors.textSecondary(isDark)),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: NaviColors.textPrimary(isDark),
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (showFallbackNote) ...[
            const SizedBox(height: 8),
            Text(
              'Try local stage names or check your connection.',
              style: TextStyle(
                  fontSize: 12, color: NaviColors.textSecondary(isDark)),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  IconData _getSourceIcon(String source) {
    if (source.contains('exact') || source.contains('Local')) {
      return Icons.directions_bus;
    } else if (source.contains('Mapbox') || source.contains('corridor')) {
      return Icons.map;
    } else if (source.contains('Cached')) {
      return Icons.cached;
    }
    return Icons.search;
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;

  /// Straight-line distance from the user to this result's resolved point.
  final double? distanceToUserMeters;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.result,
    required this.distanceToUserMeters,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExactMatch = result.source == SearchResultSource.exactStage;
    final isNoTransit = result.nearestStageName == 'No transit data nearby';
    final hasCorridor = result.matchedCorridorName != null;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isNoTransit
              ? Colors.orange.withValues(alpha: 0.12)
              : isExactMatch
                  ? AppConstants.nairobiGreen.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isNoTransit
              ? Icons.place
              : isExactMatch
                  ? Icons.directions_bus
                  : Icons.place,
          color: isNoTransit
              ? Colors.orange
              : isExactMatch
                  ? AppConstants.nairobiGreen
                  : Colors.blue,
          size: 20,
        ),
      ),
      title: Text(
        result.resolvedLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _buildSecondaryLine(isExactMatch, hasCorridor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: NaviColors.textSecondary(isDark), fontSize: 12),
          ),
          if (result.routeNumbers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: result.routeNumbers.map((r) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: (isExactMatch ? AppConstants.nairobiGreen : Colors.blue)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    r,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isExactMatch ? AppConstants.nairobiGreen : Colors.blue,
                    ),
                  ),
                )).toList(),
              ),
            ),
        ],
      ),
      isThreeLine: result.routeNumbers.isNotEmpty,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (distanceToUserMeters != null &&
              distanceToUserMeters!.isFinite)
            Text(
              '${DistanceFormatter.format(distanceToUserMeters!)} away',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: NaviColors.textSecondary(isDark),
              ),
            ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isExactMatch
                  ? AppConstants.nairobiGreen.withValues(alpha: 0.1)
                  : isNoTransit
                      ? Colors.orange.withValues(alpha: 0.12)
                      : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isExactMatch ? 'Stage' : (isNoTransit ? 'Place' : 'Place'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isExactMatch
                    ? AppConstants.nairobiGreen
                    : isNoTransit
                        ? Colors.orange.shade700
                        : Colors.blue,
              ),
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _buildSecondaryLine(bool isExactMatch, bool hasCorridor) {
    if (isExactMatch) {
      return result.routeNumbers.isNotEmpty
          ? 'Stage · ${result.routeNumbers.join(', ')} routes'
          : 'Nairobi stage';
    }
    if (result.secondaryLine != null && result.secondaryLine!.isNotEmpty) {
      return result.secondaryLine!;
    }
    if (hasCorridor) {
      return 'Near ${result.matchedCorridorName} corridor';
    }
    return 'Resolved place';
  }
}