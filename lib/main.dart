import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart' as home_screen;
import 'screens/main_map_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/destination_search_screen.dart';
import 'screens/submit_wait_screen.dart';
import 'screens/analytics_dashboard.dart';
import 'screens/profile_screen.dart';

import 'providers/app_state_provider.dart';
import 'services/settings_service.dart';
import 'providers/navigation_provider.dart';
import 'providers/journey_provider.dart';
import 'viewmodels/search_viewmodel.dart';
import 'viewmodels/active_journey_viewmodel.dart';

import 'core/constants.dart';
import 'core/theme.dart';
import 'services/database/local_storage_service.dart';

import 'models/transport_models.dart';
import 'features/settings/settings_screen.dart';
import 'features/community/providers/community_provider.dart';
import 'features/community/screens/community_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  await LocalStorageService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
        ChangeNotifierProvider(create: (_) {
          final service = SettingsService();
          service.load();
          return service;
        }),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = JourneyProvider();
          provider.loadPreferences();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
        ChangeNotifierProvider(create: (_) => SearchViewModel()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: AppConstants.appName,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode:
                settings.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingScreen();
                }
                if (snapshot.hasData && snapshot.data != null) {
                  return const home_screen.HomeScreen();
                }
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
              '/analytics': (context) => const AnalyticsDashboard(),
              '/community': (context) => const CommunityScreen(),
              '/map': (context) => const MainMapScreen(),
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.nairobiGreen,
              Color(0xFF00B36B),
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
