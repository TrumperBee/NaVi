import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navi_app/features/community/providers/community_provider.dart';
import 'package:navi_app/features/community/models/community_models.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommunityProvider>();
    final community = provider.communityService;
    final moderation = provider.moderationService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderation'),
        backgroundColor: const Color(0xFF008751),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: 'Suggestions (${community.pendingStageSuggestions.length + community.pendingRouteSuggestions.length})'),
            Tab(text: 'Reports (${moderation.unresolvedReports.length})'),
            const Tab(text: 'Log'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSuggestionsTab(context, community),
          _buildReportsTab(context, moderation),
          _buildLogTab(context, moderation),
        ],
      ),
    );
  }

  Widget _buildSuggestionsTab(BuildContext context, dynamic community) {
    final stages = community.pendingStageSuggestions;
    final routes = community.pendingRouteSuggestions;

    if (stages.isEmpty && routes.isEmpty) {
      return const Center(child: Text('No pending suggestions'));
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (stages.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Stage Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...stages.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(s.name),
              subtitle: Text('${s.corridor} - ${s.routes.join(", ")}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      community.approveStageSuggestion(s.id);
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      community.rejectSuggestion('stage_suggestions', s.id);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          )),
        ],
        if (routes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Route Suggestions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          ...routes.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('${s.number} - ${s.name}'),
              subtitle: Text('${s.corridor} - ${s.sacco}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () {
                      community.approveRouteSuggestion(s.id);
                      setState(() {});
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      community.rejectSuggestion('route_suggestions', s.id);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildReportsTab(BuildContext context, dynamic moderation) {
    final reports = moderation.unresolvedReports;
    if (reports.isEmpty) {
      return const Center(child: Text('No unresolved reports'));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: reports.map<Widget>((r) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _reportColor(r.category).withValues(alpha: 0.2),
            child: Icon(_reportIcon(r.category), color: _reportColor(r.category)),
          ),
          title: Text(r.reportedUserName),
          subtitle: Text('${r.category.name}: ${r.description}'),
          trailing: IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green),
            onPressed: () => moderation.resolveReport(r.id),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildLogTab(BuildContext context, dynamic moderation) {
    final log = moderation.moderationLog;
    if (log.isEmpty) {
      return const Center(child: Text('No moderation actions yet'));
    }
    return ListView(
      padding: const EdgeInsets.all(8),
      children: log.map<Widget>((r) => Card(
        margin: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: _actionColor(r.action).withValues(alpha: 0.2),
            child: Icon(_actionIcon(r.action), color: _actionColor(r.action), size: 20),
          ),
          title: Text('${r.action.name} - ${r.targetUserName}'),
          subtitle: Text(r.reason),
          trailing: Text(r.createdAt.toString().substring(0, 10), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      )).toList(),
    );
  }

  Color _reportColor(ReportCategory c) {
    switch (c) {
      case ReportCategory.spam: return Colors.orange;
      case ReportCategory.incorrect: return Colors.red;
      case ReportCategory.duplicate: return Colors.blue;
      case ReportCategory.abusive: return Colors.deepPurple;
    }
  }

  IconData _reportIcon(ReportCategory c) {
    switch (c) {
      case ReportCategory.spam: return Icons.warning;
      case ReportCategory.incorrect: return Icons.error;
      case ReportCategory.duplicate: return Icons.content_copy;
      case ReportCategory.abusive: return Icons.block;
    }
  }

  Color _actionColor(ModerationActionType a) {
    switch (a) {
      case ModerationActionType.warn: return Colors.orange;
      case ModerationActionType.suspend: return Colors.red;
      case ModerationActionType.ban: return Colors.red.shade900;
      case ModerationActionType.approve: return Colors.green;
      case ModerationActionType.reject: return Colors.red;
    }
  }

  IconData _actionIcon(ModerationActionType a) {
    switch (a) {
      case ModerationActionType.warn: return Icons.warning_amber;
      case ModerationActionType.suspend: return Icons.pause_circle;
      case ModerationActionType.ban: return Icons.gavel;
      case ModerationActionType.approve: return Icons.check_circle;
      case ModerationActionType.reject: return Icons.cancel;
    }
  }
}
