import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/models/app_settings.dart';
import 'package:navi_app/services/mapbox_config.dart';
import 'package:navi_app/services/offline_map_service.dart';
import 'package:navi_app/services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final OfflineMapService _offlineMapService = OfflineMapService();

  bool _offlineDownloading = false;
  double _offlineProgress = 0;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  /// Reads the real packaged version (e.g. "1.0.0" from pubspec), falling
  /// back to a literal only if the platform plugin is unavailable.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {
      // Keep the fallback; plugin unavailable in unit-test environments.
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsService>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader("ACCOUNT"),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppConstants.nairobiGreen.withValues(alpha: 0.1),
              child: Icon(
                Icons.person_outline,
                color: AppConstants.nairobiGreen,
              ),
            ),
            title: Text(
              user?.isAnonymous ?? true ? 'Guest User' : 'NaVi User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              user?.uid?.substring(0, 8) ?? 'Anonymous Account',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user?.isAnonymous ?? true ? 'Guest' : 'Signed In',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),

          _buildSectionHeader("NAVIGATION PREFERENCES"),
          SwitchListTile(
            secondary: _iconTile(Icons.traffic, Colors.amber),
            title: const Text("Avoid busy junctions"),
            subtitle: const Text("Route around traffic hotspots"),
            value: settings.avoidBusyJunctions,
            onChanged: (val) => settings.toggleAvoidBusyJunctions(),
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: _iconTile(Icons.directions_walk, Colors.green),
            title: const Text("Prefer walking paths"),
            subtitle: const Text("Use pedestrian-friendly routes"),
            value: settings.preferWalkingPaths,
            onChanged: (val) => settings.togglePreferWalkingPaths(),
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: _iconTile(Icons.satellite, Colors.blue),
            title: const Text("High accuracy mode"),
            subtitle: const Text("Use GPS continuously (battery heavy)"),
            value: settings.highAccuracyMode,
            onChanged: (val) => settings.toggleHighAccuracyMode(),
            activeColor: AppConstants.nairobiGreen,
          ),
          ListTile(
            leading: _iconTile(Icons.straighten, Colors.indigo),
            title: const Text("Distance Unit"),
            subtitle: Text(
                settings.distanceUnit == DistanceUnit.km
                    ? 'Kilometers (km)'
                    : 'Miles (mi)'),
            trailing: SegmentedButton<DistanceUnit>(
              segments: const [
                ButtonSegment(value: DistanceUnit.km, label: Text('km')),
                ButtonSegment(value: DistanceUnit.mi, label: Text('mi')),
              ],
              selected: {settings.distanceUnit},
              onSelectionChanged: (val) => settings.setDistanceUnit(val.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),

          _buildSectionHeader("APP PREFERENCES"),
          SwitchListTile(
            secondary: _iconTile(
              settings.isDarkTheme ? Icons.nightlight_round : Icons.wb_sunny,
              settings.isDarkTheme ? Colors.grey : Colors.amber,
            ),
            title: const Text("Dark Mode"),
            subtitle: Text(settings.isDarkTheme
                ? "Mapbox Night: ${MapboxConfig.darkStyle.split('/').last}"
                : "Mapbox Day: ${MapboxConfig.lightStyle.split('/').last}"),
            value: settings.isDarkTheme,
            onChanged: (val) => settings.toggleTheme(),
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: _iconTile(Icons.notifications, Colors.red),
            title: const Text("Notifications"),
            subtitle: const Text("Get alerts about wait times"),
            value: settings.notificationsEnabled,
            onChanged: (val) => settings.toggleNotifications(),
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: _iconTile(Icons.record_voice_over, Colors.deepPurple),
            title: const Text("Voice Guidance"),
            subtitle: const Text("Spoken turn-by-turn directions"),
            value: settings.voiceGuidanceEnabled,
            onChanged: (val) => settings.toggleVoiceGuidance(),
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: _iconTile(Icons.location_on, Colors.purple),
            title: const Text("Location Sharing"),
            subtitle: const Text("Help others by sharing your location"),
            value: settings.locationSharingEnabled,
            onChanged: (val) => settings.toggleLocationSharing(),
            activeColor: AppConstants.nairobiGreen,
          ),

          _buildSectionHeader("DATA MANAGEMENT"),
          ListTile(
            leading: _iconTile(Icons.history, Colors.orange),
            title: const Text("Clear Journey History"),
            subtitle: const Text("Remove all your past trips"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _confirmClearHistory(context, settings),
          ),
          _buildOfflineMapTile(),

          _buildSectionHeader("YOUR STATS"),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Contribution',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Reports', settings.reportsSubmitted.toString(), Icons.timer),
                      _buildStatItem('Journeys', settings.completedJourneys.toString(), Icons.route),
                      _buildStatItem('Contributions', settings.totalContributions.toString(), Icons.emoji_events),
                    ],
                  ),
                  if (settings.totalKmTraveled > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          '${settings.totalKmTraveled.toStringAsFixed(1)} km total traveled',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/analytics'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.nairobiGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('View Detailed Analytics'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          _buildSectionHeader("ABOUT"),
          Card(
            child: ListTile(
              leading: _iconTile(Icons.info_outline, AppConstants.nairobiGreen),
              title: const Text('About NaVi'),
              subtitle: Text('Version $_appVersion'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              onTap: () => _showAboutDialog(context),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out successfully')),
                  );
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _iconTile(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppConstants.nairobiGreen, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  void _confirmClearHistory(BuildContext context, SettingsService settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear History"),
        content: const Text(
          "Are you sure? This will delete all journey history, stats, and cached searches."
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              settings.clearJourneyHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Journey history cleared successfully")),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineMapTile() {
    return ListTile(
      leading: _iconTile(Icons.download, Colors.teal),
      title: const Text("Download Offline Maps"),
      subtitle: Text(_offlineDownloading
          ? "Downloading Nairobi offline map... ${(_offlineProgress * 100).round()}%"
          : "Save Nairobi map for offline use"),
      trailing: _offlineDownloading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                value: _offlineProgress > 0 ? _offlineProgress : null,
                strokeWidth: 2,
                color: AppConstants.nairobiGreen,
              ),
            )
          : const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: _offlineDownloading ? null : () => _handleOfflineMaps(context),
    );
  }

  void _handleOfflineMaps(BuildContext context) {
    setState(() {
      _offlineDownloading = true;
      _offlineProgress = 0;
    });
    _offlineMapService.downloadRegion(
      onProgress: (progress) {
        if (mounted) setState(() => _offlineProgress = progress.clamp(0.0, 1.0));
      },
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _offlineDownloading = false;
          _offlineProgress = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Nairobi offline map downloaded successfully")),
        );
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _offlineDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Offline map download failed: $error"),
          ),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: AppConstants.appName,
      applicationVersion: _appVersion,
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppConstants.nairobiGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.directions_bus, color: Colors.white, size: 28),
      ),
      applicationLegalese: '\u00a9 2026 NaVi Team',
      children: [
        const SizedBox(height: 16),
        const Text(
          'NaVi helps you navigate Nairobi\'s matatu system by providing '
          'real-time wait time predictions based on community reports. '
          'Know your wait before you arrive at the stage.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),
        Text(
          'Powered by Mapbox, OSRM, and the NaVi community.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
