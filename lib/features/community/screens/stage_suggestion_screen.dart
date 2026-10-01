import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navi_app/features/community/providers/community_provider.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/data/seed_data.dart';

class StageSuggestionScreen extends StatefulWidget {
  const StageSuggestionScreen({super.key});

  @override
  State<StageSuggestionScreen> createState() => _StageSuggestionScreenState();
}

class _StageSuggestionScreenState extends State<StageSuggestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCorridor = 'CBD';
  List<String> _selectedRoutes = [];
  String? _selectedArea;
  int _suggestionCount = 0;

  final List<String> _corridors = ['CBD', 'Eastlands', 'Westlands', 'South B', 'South C', 'Ngong Road', 'Thika Road', 'Mombasa Road', 'Kangemi', 'Other'];
  final List<String> _areas = ['Nairobi CBD', 'Eastlands', 'Westlands', 'South B', 'South C', 'Kibera', 'Kawangware', 'Githurai', 'Ruiru', 'Kasarani', 'Embakasi', 'Other'];
  final List<String> _allRoutes = ['44', '45', '111', '24', '58', '10', '110', '114', '33', '34', '35', '145', '146', '147', '125', '126', '5', '105', '106', '107'];

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggest a Stage'),
        backgroundColor: const Color(0xFF008751),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Stage Name',
                hintText: 'e.g., Kencom, Railway, etc.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.directions_bus),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter stage name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCorridor,
              decoration: const InputDecoration(
                labelText: 'Corridor',
                border: OutlineInputBorder(),
                prefixIcon: const Icon(Icons.route),
              ),
              items: _corridors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCorridor = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedArea,
              decoration: const InputDecoration(
                labelText: 'Area (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
              items: _areas.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (v) => setState(() => _selectedArea = v),
            ),
            const SizedBox(height: 16),
            const Text('Routes Serving This Stage:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _allRoutes.map((route) {
                final selected = _selectedRoutes.contains(route);
                return FilterChip(
                  label: Text('Route $route'),
                  selected: selected,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) { _selectedRoutes.add(route); }
                      else { _selectedRoutes.remove(route); }
                    });
                  },
                  selectedColor: const Color(0xFF008751).withValues(alpha: 0.2),
                  checkmarkColor: const Color(0xFF008751),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional info about this stage',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.send),
                label: const Text('Submit Suggestion'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF008751),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoutes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one route'), backgroundColor: Colors.red),
      );
      return;
    }

    final provider = context.read<CommunityProvider>();
    if (!provider.antiSpamService.canSubmitSuggestion('user')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too many suggestions. Please wait.'), backgroundColor: Colors.red),
      );
      return;
    }

    final suggestion = CommunityStageSuggestion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SuggestionType.create,
      name: _nameController.text.trim(),
      latitude: -1.2833,
      longitude: 36.8167,
      corridor: _selectedCorridor,
      routes: _selectedRoutes,
      area: _selectedArea,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      userId: 'user',
    );

    final id = await provider.communityService.suggestStage(suggestion);
    if (id != null && context.mounted) {
      provider.antiSpamService.recordSuggestion('user');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stage suggestion submitted!'), backgroundColor: Color(0xFF008751)),
      );
      Navigator.pop(context);
    }
  }
}
