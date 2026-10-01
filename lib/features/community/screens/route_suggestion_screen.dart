import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navi_app/features/community/providers/community_provider.dart';
import 'package:navi_app/features/community/models/community_models.dart';
import 'package:navi_app/data/seed_data.dart';

class RouteSuggestionScreen extends StatefulWidget {
  const RouteSuggestionScreen({super.key});

  @override
  State<RouteSuggestionScreen> createState() => _RouteSuggestionScreenState();
}

class _RouteSuggestionScreenState extends State<RouteSuggestionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  final _nameController = TextEditingController();
  final _fareController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedCorridor = 'CBD';
  String _selectedSacco = 'Super Metro';
  List<String> _selectedStops = [];

  final List<String> _corridors = ['CBD', 'Eastlands', 'Westlands', 'South B', 'Ngong Road', 'Thika Road', 'Mombasa Road', 'Kangemi'];
  final List<String> _saccos = ['Super Metro', 'City Hoppa', 'Kenya Bus', 'Citi Hoppa', 'Embassava', 'KBS', 'Metrotrans', 'Mombasa Raha', 'Other'];

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    _fareController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggest a Route'),
        backgroundColor: const Color(0xFF008751),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _numberController,
              decoration: const InputDecoration(
                labelText: 'Route Number',
                hintText: 'e.g., 44, 111, 24',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter route number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Route Name',
                hintText: 'e.g., CBD - Kayole',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.route),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Enter route name' : null,
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
              value: _selectedSacco,
              decoration: const InputDecoration(
                labelText: 'Sacco',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              items: _saccos.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _selectedSacco = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fareController,
              decoration: const InputDecoration(
                labelText: 'Base Fare (KSh)',
                hintText: 'e.g., 50',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Additional info about this route',
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

    final provider = context.read<CommunityProvider>();
    if (!provider.antiSpamService.canSubmitSuggestion('user')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Too many suggestions. Please wait.'), backgroundColor: Colors.red),
      );
      return;
    }

    final suggestion = CommunityRouteSuggestion(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: SuggestionType.create,
      number: _numberController.text.trim(),
      name: _nameController.text.trim(),
      corridor: _selectedCorridor,
      sacco: _selectedSacco,
      stops: _selectedStops,
      baseFare: double.tryParse(_fareController.text) ?? 0,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      userId: 'user',
    );

    final id = await provider.communityService.suggestRoute(suggestion);
    if (id != null && context.mounted) {
      provider.antiSpamService.recordSuggestion('user');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route suggestion submitted!'), backgroundColor: Color(0xFF008751)),
      );
      Navigator.pop(context);
    }
  }
}
