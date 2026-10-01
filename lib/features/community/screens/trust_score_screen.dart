import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navi_app/features/community/providers/community_provider.dart';

class TrustScoreScreen extends StatelessWidget {
  const TrustScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final score = provider.trustScoreService.currentScore;
    final leaderboard = provider.trustScoreService.leaderboard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trust Scores'),
        backgroundColor: const Color(0xFF008751),
        foregroundColor: Colors.white,
      ),
      body: score == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildScoreCard(score),
                const SizedBox(height: 24),
                const Text('Leaderboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (leaderboard.isEmpty)
                  const Card(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No data yet. Start contributing!', textAlign: TextAlign.center),
                  ))
                else
                  ...leaderboard.take(20).toList().asMap().entries.map((entry) => Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _rankColor(entry.key + 1).withValues(alpha: 0.2),
                        child: Text('${entry.key + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: _rankColor(entry.key + 1))),
                      ),
                      title: Text(entry.value.userName),
                      subtitle: Text('Level: ${entry.value.level.name}'),
                      trailing: Text('${entry.value.score.toStringAsFixed(0)} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )),
              ],
            ),
    );
  }

  Widget _buildScoreCard(dynamic score) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF008751), const Color(0xFF00B36B)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text('Your Trust Score', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(score.score.toStringAsFixed(0), style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(score.level.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ),
          const SizedBox(height: 16),
          _buildStat('Reports Submitted', score.reportsSubmitted.toString()),
          _buildStat('Reports Confirmed', score.reportsConfirmed.toString()),
          _buildStat('Suggestions Approved', score.suggestionsApproved.toString()),
          _buildStat('Verifications', score.verificationsPerformed.toString()),
          if (score.flagsReceived > 0)
            _buildStat('Flags Received', score.flagsReceived.toString(), isWarning: true),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isWarning ? Colors.orange : Colors.white70, fontSize: 13)),
          Text(value, style: TextStyle(color: isWarning ? Colors.orange : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Color _rankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank == 2) return Colors.grey;
    if (rank == 3) return Colors.brown;
    return Colors.blue;
  }
}
