import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens
import 'screens/home_map_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/destination_search_screen.dart';
import 'screens/submit_wait_screen.dart';

// Providers
import 'providers/app_state_provider.dart';

// Utils
import 'utils/constants.dart';

// Models
import 'models/stage_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppStateProvider(),
      child: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return MaterialApp(
            title: AppConstants.appName,
            theme: appState.themeData,
            debugShowCheckedModeBanner: false,
            // StreamBuilder listens to Firebase Auth state
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                // Show loading while checking auth state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingScreen();
                }
                
                // User is authenticated
                if (snapshot.hasData && snapshot.data != null) {
                  return const HomeMapScreen();
                }
                
                // User is NOT authenticated - show Auth Screen
                return const AuthScreen();
              },
            ),
            routes: {
              '/search': (context) => const DestinationSearchScreen(),
              '/submit': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is StageModel) {
                  return SubmitWaitScreen(initialStage: args);
                }
                return const SubmitWaitScreen();
              },
              '/settings': (context) => const SettingsScreen(),
              '/profile': (context) => const ProfileScreen(),
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.nairobiGreen,
              AppConstants.nairobiGreen.withOpacity(0.7),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              SizedBox(height: 16),
              Text(
                'Loading NaVi...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Toggle
          Card(
            child: ListTile(
              leading: Icon(
                appState.isDarkTheme ? Icons.nightlight_round : Icons.wb_sunny,
                color: AppConstants.nairobiGreen,
              ),
              title: const Text('Theme'),
              subtitle: Text(appState.isDarkTheme ? 'Nairobi Night' : 'Nairobi Day'),
              trailing: Switch(
                value: appState.isDarkTheme,
                onChanged: (_) => appState.toggleTheme(),
                activeColor: AppConstants.nairobiGreen,
              ),
            ),
          ),
          
          // Notifications
          Card(
            child: ListTile(
              leading: const Icon(Icons.notifications, color: AppConstants.nairobiGreen),
              title: const Text('Notifications'),
              subtitle: const Text('Get alerts about wait times'),
              trailing: Switch(
                value: appState.notificationsEnabled,
                onChanged: (_) => appState.toggleNotifications(),
                activeColor: AppConstants.nairobiGreen,
              ),
            ),
          ),
          
          // Location Sharing
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on, color: AppConstants.nairobiGreen),
              title: const Text('Location Sharing'),
              subtitle: const Text('Help others by sharing your location'),
              trailing: Switch(
                value: appState.locationSharingEnabled,
                onChanged: (_) => appState.toggleLocationSharing(),
                activeColor: AppConstants.nairobiGreen,
              ),
            ),
          ),
          
          // Stats
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Contribution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        'Reports',
                        appState.reportsSubmitted.toString(),
                        Icons.timer,
                      ),
                      _buildStatItem(
                        'Routes',
                        '15',
                        Icons.route,
                      ),
                      _buildStatItem(
                        'Stages',
                        '23',
                        Icons.location_on,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // About Section
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About NaVi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'NaVi helps you navigate Nairobi\'s matatu system by providing '
                    'real-time wait time predictions based on community reports. '
                    'Know your wait before you arrive at the stage.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Sign Out Button
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signed out successfully')),
                  );
                }
              },
            ),
          ),
        ],
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// Profile Screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppConstants.nairobiGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person,
                size: 50,
                color: AppConstants.nairobiGreen,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.uid ?? 'Anonymous User',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.isAnonymous ?? true ? 'Anonymous Account' : 'Signed In',
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out successfully'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}