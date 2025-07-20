import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/services/prbo_execution_service.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PrboCreateExecutionSheetScreen extends StatefulWidget {
  final String jwtToken;
  final String username;
  final ExecutionSheet? editingSheet; // For editing existing sheets

  const PrboCreateExecutionSheetScreen({
    Key? key,
    required this.jwtToken,
    required this.username,
    this.editingSheet,
  }) : super(key: key);

  @override
  _PrboCreateExecutionSheetScreenState createState() =>
      _PrboCreateExecutionSheetScreenState();
}

class _PrboCreateExecutionSheetScreenState
    extends State<PrboCreateExecutionSheetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedWorksheetId;
  String? _selectedState;

  List<Map<String, dynamic>> _availableWorksheets = [];
  bool _isLoading = false;
  bool _isLoadingWorksheets = false;

  final List<String> _executionStates = ['PENDING', 'IN_PROGRESS', 'COMPLETED'];

  bool get _isEditing => widget.editingSheet != null;

  @override
  void initState() {
    super.initState();

    if (_isEditing) {
      _populateEditingData();
    } else {
      _loadAvailableWorksheets();
    }
  }

  void _populateEditingData() {
    final sheet = widget.editingSheet!;
    _titleController.text = sheet.title;
    _descriptionController.text = sheet.description ?? '';
    // Note: Worksheet ID is not editable after creation, so we don't set _selectedWorksheetId
    _selectedState = sheet.state;
  }

  Future<void> _loadAvailableWorksheets() async {
    setState(() {
      _isLoadingWorksheets = true;
    });

    try {
      final worksheets = await PrboExecutionService.fetchAvailableWorksheets(
        jwtToken: widget.jwtToken,
      );

      setState(() {
        _availableWorksheets = worksheets;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load available worksheets: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingWorksheets = false;
      });
    }
  }

  Future<void> _saveExecutionSheet() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Only validate worksheet selection for new sheets, not for editing
    if (!_isEditing && _selectedWorksheetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a worksheet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditing) {
        // Update existing execution sheet (without changing worksheet)
        await PrboExecutionService.updateExecutionSheet(
          jwtToken: widget.jwtToken,
          sheetId: widget.editingSheet!.id,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          state: _selectedState,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Execution sheet updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Create new execution sheet
        await PrboExecutionService.createExecutionSheet(
          jwtToken: widget.jwtToken,
          title: _titleController.text.trim(),
          associatedWorkSheetId: _selectedWorksheetId!,
          description: _descriptionController.text.trim(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Execution sheet created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      Navigator.of(context).pop(); // Return to previous screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save execution sheet: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Execution Sheet' : 'Create Execution Sheet',
        ),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveExecutionSheet,
              child: Text(
                _isEditing ? 'UPDATE' : 'CREATE',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Field
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title*',
                          hintText: 'Enter execution sheet title',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Enter optional description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Worksheet Selection (only for creating new sheets)
              if (!_isEditing) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Worksheet Assignment',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _isLoadingWorksheets
                            ? const Center(child: CircularProgressIndicator())
                            : DropdownButtonFormField<String>(
                                value: _selectedWorksheetId,
                                decoration: const InputDecoration(
                                  labelText: 'Associated Worksheet*',
                                  hintText: 'Select a worksheet',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.assignment),
                                ),
                                items: _availableWorksheets.map((worksheet) {
                                  return DropdownMenuItem<String>(
                                    value: worksheet['id']?.toString(),
                                    child: Text(
                                      worksheet['title']?.toString() ??
                                          'Unknown Worksheet',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedWorksheetId = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please select a worksheet';
                                  }
                                  return null;
                                },
                              ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],

              // State Selection (only for editing)
              if (_isEditing) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Execution State',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedState,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            hintText: 'Select execution state',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.settings),
                          ),
                          items: _executionStates.map((state) {
                            return DropdownMenuItem<String>(
                              value: state,
                              child: Text(state.replaceAll('_', ' ')),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedState = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveExecutionSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          _isEditing
                              ? 'Update Execution Sheet'
                              : 'Create Execution Sheet',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
