import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Fix imports - use navi_app
import 'package:navi_app/utils/constants.dart';
import 'package:navi_app/providers/app_state_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        children: [
          // User Profile Section
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
          ),

          // Navigation Preferences
          _buildSectionHeader("NAVIGATION PREFERENCES"),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.traffic, color: Colors.amber),
            ),
            title: const Text("Avoid busy junctions"),
            subtitle: const Text("Route around traffic hotspots"),
            value: true,
            onChanged: (val) {},
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.directions_walk, color: Colors.green),
            ),
            title: const Text("Prefer walking paths"),
            subtitle: const Text("Use pedestrian-friendly routes"),
            value: false,
            onChanged: (val) {},
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.satellite, color: Colors.blue),
            ),
            title: const Text("High accuracy mode"),
            subtitle: const Text("Use GPS continuously (battery heavy)"),
            value: true,
            onChanged: (val) {},
            activeColor: AppConstants.nairobiGreen,
          ),

          // App Preferences
          _buildSectionHeader("APP PREFERENCES"),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: appState.isDarkTheme
                    ? Colors.grey.withValues(alpha: 0.1)
                    : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                appState.isDarkTheme ? Icons.nightlight_round : Icons.wb_sunny,
                color: appState.isDarkTheme ? Colors.grey : Colors.amber,
              ),
            ),
            title: const Text("Dark Mode"),
            subtitle:
                Text(appState.isDarkTheme ? "Nairobi Night" : "Nairobi Day"),
            value: appState.isDarkTheme,
            onChanged: (val) => appState.toggleTheme(),
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications, color: Colors.red),
            ),
            title: const Text("Notifications"),
            subtitle: const Text("Get alerts about wait times"),
            value: appState.notificationsEnabled,
            onChanged: (val) => appState.toggleNotifications(),
            activeColor: AppConstants.nairobiGreen,
          ),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on, color: Colors.purple),
            ),
            title: const Text("Location Sharing"),
            subtitle: const Text("Help others by sharing your location"),
            value: appState.locationSharingEnabled,
            onChanged: (val) => appState.toggleLocationSharing(),
            activeColor: AppConstants.nairobiGreen,
          ),

          // Data Management
          _buildSectionHeader("DATA MANAGEMENT"),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.history, color: Colors.orange),
            ),
            title: const Text("Clear Journey History"),
            subtitle: const Text("Remove all your past trips"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Clear History"),
                  content: const Text(
                      "Are you sure you want to delete all your journey history?"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Clear history logic
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("History cleared")),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text("Clear"),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.download, color: Colors.teal),
            ),
            title: const Text("Download Offline Maps"),
            subtitle: const Text("Save Nairobi map for offline use"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Offline maps coming soon!")),
              );
            },
          ),

          // About Section
          _buildSectionHeader("ABOUT"),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppConstants.nairobiGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.info,
                color: AppConstants.nairobiGreen,
              ),
            ),
            title: const Text("App Version"),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "1.0.2 (Beta)",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star, color: Colors.blue),
            ),
            title: const Text("Rate NaVi"),
            subtitle: const Text("Love the app? Leave a review"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Rate us on Play Store!")),
              );
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.share, color: Colors.purple),
            ),
            title: const Text("Share NaVi"),
            subtitle: const Text("Tell your friends about us"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Share dialog coming soon!")),
              );
            },
          ),

          const SizedBox(height: 20),

          // Sign Out Button (only for non-anonymous users or always show)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text("Sign Out"),
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
}
