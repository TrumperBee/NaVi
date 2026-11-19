import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:navi_app/core/constants.dart';
import 'package:navi_app/services/settings_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Contact/report actions. The developer WhatsApp number.
  static const String _supportPhone = '254713079528';

  /// Opens [url] in the matching external app.
  ///
  /// Deliberately does NOT gate on `canLaunchUrl`: on Android 15 that check
  /// returns false for valid https/mailto/wa.me links because package
  /// visibility is scoped, which made every button on this screen a silent
  /// no-op. Attempt the launch and surface a real error only on failure.
  Future<void> _openExternal(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        messenger.showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Future<void> _launchEmail(BuildContext context, String email) =>
      _openExternal(context, 'mailto:$email');

  Future<void> _launchWhatsApp(BuildContext context, String phone) =>
      _openExternal(context, 'https://wa.me/$phone');

  Future<void> _launchURL(BuildContext context, String url) =>
      _openExternal(context, url);

  /// Report/suggestion tiles hand off to the support WhatsApp chat with a
  /// prefilled opener, so they do something real instead of "coming soon".
  Future<void> _sendSupportMessage(BuildContext context, String message) =>
      _openExternal(
        context,
        'https://wa.me/$_supportPhone?text=${Uri.encodeComponent(message)}',
      );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final settings = context.watch<SettingsService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppConstants.nairobiGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppConstants.nairobiGreen,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 50,
                      color: AppConstants.nairobiGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.isAnonymous ?? true ? 'NaVi User' : 'Victor Ochieng',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.uid?.substring(0, 8) ?? 'Guest User',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Beta Tester',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Your Stats'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('Trips', '${settings.completedJourneys}',
                        Icons.directions_bus),
                    _buildStatItem('Reports', '${settings.reportsSubmitted}',
                        Icons.timer),
                    _buildStatItem('Stages', '${settings.distinctStages}',
                        Icons.location_on),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Your Contribution'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('KM Travelled',
                        settings.totalKmTraveled.toStringAsFixed(1),
                        Icons.route),
                    _buildStatItem('Trips Reported', '${settings.reportsSubmitted}',
                        Icons.rate_review),
                    _buildStatItem('Total Contributions',
                        '${settings.totalContributions}',
                        Icons.volunteer_activism),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Help & Support'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.report_problem, color: Colors.red),
                    ),
                    title: const Text('Report Route Issue'),
                    subtitle: const Text('Incorrect route information'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _sendSupportMessage(
                      context,
                      'Hi NaVi, I want to report a route issue: ',
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.attach_money, color: Colors.orange),
                    ),
                    title: const Text('Report Fare Issue'),
                    subtitle: const Text('Incorrect fare information'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _sendSupportMessage(
                      context,
                      'Hi NaVi, I want to report a fare issue: ',
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add_location, color: Colors.green),
                    ),
                    title: const Text('Suggest New Stage'),
                    subtitle: const Text('Help us expand our coverage'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _sendSupportMessage(
                      context,
                      'Hi NaVi, I want to suggest a new stage: ',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Developer Info'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: AppConstants.nairobiGreen),
                        SizedBox(width: 12),
                        Text(
                          'Victor Ochieng',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 0),
                    const SizedBox(height: 12),
                    _buildContactTile(
                      icon: Icons.email,
                      color: Colors.red,
                      label: 'ochiengv250@gmail.com',
                      onTap: () =>
                          _launchEmail(context, 'ochiengv250@gmail.com'),
                    ),
                    _buildContactTile(
                      icon: Icons.message,
                      color: Colors.green,
                      label: '+254 713 079 528',
                      onTap: () => _launchWhatsApp(context, _supportPhone),
                    ),
                    _buildContactTile(
                      icon: Icons.camera_alt,
                      color: Colors.purple,
                      label: '@404._victor',
                      onTap: () => _launchURL(
                          context, 'https://instagram.com/404._victor'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!(user?.isAnonymous ?? true))
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
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.grey[800],
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

  Widget _buildContactTile({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.open_in_new, size: 16, color: Colors.grey),
      onTap: onTap,
      dense: true,
    );
  }
}
