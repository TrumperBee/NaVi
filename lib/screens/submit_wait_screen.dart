import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Fix imports - use transport_models.dart
import 'package:navi_app/models/transport_models.dart';
import 'package:navi_app/models/wait_report_model.dart';
import 'package:navi_app/services/database_service.dart';
import 'package:navi_app/utils/constants.dart';
import 'package:navi_app/providers/app_state_provider.dart';
import 'package:navi_app/services/settings_service.dart';
import 'package:navi_app/data/seed_data.dart';

class SubmitWaitScreen extends StatefulWidget {
  final StageModel? initialStage;

  const SubmitWaitScreen({super.key, this.initialStage});

  @override
  State<SubmitWaitScreen> createState() => _SubmitWaitScreenState();
}

class _SubmitWaitScreenState extends State<SubmitWaitScreen> {
  final DatabaseService _databaseService = DatabaseService();
  
  StageModel? _selectedStage;
  RouteModel? _selectedRoute;
  String? _selectedSacco;
  int? _selectedWaitTime;
  bool _isSubmitting = false;
  bool _isLoading = true;

  List<StageModel> _stages = [];
  List<RouteModel> _routes = [];
  List<RouteModel> _filteredRoutes = [];

  @override
  void initState() {
    super.initState();
    _selectedStage = widget.initialStage;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load stages from seed data first (for development)
      // In production, you would fetch from Firestore
      _stages = SeedData.getStages();
      _routes = SeedData.getRoutes();

      // Match initial stage to local instance for dropdown value match
      if (widget.initialStage != null) {
        final match = _stages.where((s) => s.id == widget.initialStage!.id);
        if (match.isNotEmpty) {
          _selectedStage = match.first;
        }
      }
      
      // If we have an initial stage, filter routes for it
      if (_selectedStage != null) {
        _filterRoutesForStage(_selectedStage!);
      }
    } catch (e) {
      print('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _filterRoutesForStage(StageModel stage) {
    if (stage.routes.isNotEmpty) {
      setState(() {
        _filteredRoutes = _routes.where((route) {
          return stage.routes.contains(route.number);
        }).toList();
      });
    } else {
      setState(() {
        _filteredRoutes = [];
      });
    }
  }

  Future<void> _submitReport() async {
    if (_selectedStage == null || 
        _selectedRoute == null || 
        _selectedWaitTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final now = DateTime.now();
      
      final newReport = WaitReportModel(
        stageId: _selectedStage!.id,
        routeId: _selectedRoute!.id,
        waitTime: _selectedWaitTime!,
        timestamp: now,
        dayOfWeek: now.weekday,
        hourOfDay: now.hour,
      );

      final reportId = await _databaseService.submitReport(newReport);

      if (reportId != null) {
        if (mounted) {
          Provider.of<AppStateProvider>(context, listen: false).incrementReportsSubmitted();
          // Keep the persistent SettingsService counter in sync so Profile's
          // "Reports" statistic reflects every successful submission.
          context.read<SettingsService>().incrementReportsSubmitted();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Wait time reported successfully!'),
              backgroundColor: AppConstants.nairobiGreen,
            ),
          );
          
          Navigator.pop(context);
        }
      } else {
        throw Exception('Failed to save report');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Report Wait Time'),
          backgroundColor: AppConstants.nairobiGreen,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Wait Time'),
        backgroundColor: AppConstants.nairobiGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stage selection
            const Text(
              'Select Stage',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<StageModel>(
              value: _selectedStage,
              hint: const Text('Choose a stage'),
              isExpanded: true,
              items: _stages.map((StageModel stage) {
                return DropdownMenuItem<StageModel>(
                  value: stage,
                  child: Text(stage.name),
                );
              }).toList(),
              onChanged: (StageModel? stage) {
                setState(() {
                  _selectedStage = stage;
                  _selectedRoute = null;
                  if (stage != null) {
                    _filterRoutesForStage(stage);
                  } else {
                    _filteredRoutes = [];
                  }
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Route selection - FIXED with proper typing
            const Text(
              'Select Route',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RouteModel>(
              value: _selectedRoute,
              hint: const Text('Choose a route'),
              isExpanded: true,
              items: _filteredRoutes.map<DropdownMenuItem<RouteModel>>((RouteModel route) {
                return DropdownMenuItem<RouteModel>(
                  value: route,
                  child: Text('${route.number} - ${route.name}'), // Uses number field
                );
              }).toList(),
              onChanged: _filteredRoutes.isEmpty ? null : (RouteModel? newValue) {
                setState(() {
                  _selectedRoute = newValue;
                  _selectedSacco = newValue?.sacco; // Uses sacco field
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Sacco (auto-filled but editable)
            const Text(
              'Sacco',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSacco,
              hint: const Text('Select or confirm Sacco'),
              isExpanded: true,
              items: AppConstants.saccos.map((String sacco) {
                return DropdownMenuItem<String>(
                  value: sacco,
                  child: Text(sacco),
                );
              }).toList(),
              onChanged: (String? sacco) {
                setState(() {
                  _selectedSacco = sacco;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Wait time selection
            const Text(
              'Wait Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3,
              children: [
                _buildWaitTimeButton(3, '0-5 min'),
                _buildWaitTimeButton(8, '5-10 min'),
                _buildWaitTimeButton(13, '10-15 min'),
                _buildWaitTimeButton(18, '15+ min'),
              ],
            ),
            
            const SizedBox(height: 30),
            
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.nairobiGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit Report',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaitTimeButton(int minutes, String label) {
    final isSelected = _selectedWaitTime == minutes;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedWaitTime = minutes;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.nairobiGreen : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}