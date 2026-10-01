import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navi_app/features/community/providers/community_provider.dart';
import 'package:navi_app/features/community/screens/stage_suggestion_screen.dart';
import 'package:navi_app/features/community/screens/route_suggestion_screen.dart';
import 'package:navi_app/features/community/screens/fare_intelligence_screen.dart';
import 'package:navi_app/features/community/screens/health_dashboard_screen.dart';
import 'package:navi_app/features/community/screens/trust_score_screen.dart';
import 'package:navi_app/features/community/screens/moderation_screen.dart';

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final pendingStages = provider.communityService.pendingStageSuggestions.length;
    final pendingRoutes = provider.communityService.pendingRouteSuggestions.length;
    final canModerate = provider.trustScoreService.canModerate('');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport Network'),
        backgroundColor: const Color(0xFF008751),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => provider.refreshAll(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Community', Icons.people, context),
          const SizedBox(height: 8),
          _buildCard(
            context,
            icon: Icons.directions_bus,
            title: 'Suggest a Stage',
            subtitle: 'Add or edit a matatu stage',
            color: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const StageSuggestionScreen(),
            )),
          ),
          const SizedBox(height: 8),
          _buildCard(
            context,
            icon: Icons.route,
            title: 'Suggest a Route',
            subtitle: 'Add or update route information${pendingRoutes > 0 ? ' ($pendingRoutes pending)' : ''}',
            color: Colors.orange,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const RouteSuggestionScreen(),
            )),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Fare Intelligence', Icons.trending_up, context),
          const SizedBox(height: 8),
          _buildCard(
            context,
            icon: Icons.attach_money,
            title: 'Fare Trends & Analysis',
            subtitle: 'Compare fares across stages and routes',
            color: Colors.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const FareIntelligenceScreen(),
            )),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Transport Health', Icons.monitor_heart, context),
          const SizedBox(height: 8),
          _buildCard(
            context,
            icon: Icons.dashboard,
            title: 'Health Dashboard',
            subtitle: 'Reliability, congestion, and performance metrics',
            color: Colors.purple,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const HealthDashboardScreen(),
            )),
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Reputation', Icons.stars, context),
          const SizedBox(height: 8),
          _buildCard(
            context,
            icon: Icons.leaderboard,
            title: 'Trust Scores & Leaderboard',
            subtitle: 'See top contributors and your reputation',
            color: Colors.teal,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => const TrustScoreScreen(),
            )),
          ),
          if (canModerate) ...[
            const SizedBox(height: 24),
            _buildSectionHeader('Moderation', Icons.shield, context),
            const SizedBox(height: 8),
            _buildCard(
              context,
              icon: Icons.admin_panel_settings,
              title: 'Moderation Panel',
              subtitle: 'Review suggestions, reports, and take action',
              color: Colors.red,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const ModerationScreen(),
              )),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF008751)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold,
        )),
      ],
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
