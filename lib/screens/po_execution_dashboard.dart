import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/services/execution_service.dart';
import 'package:trailblaze_app/screens/po_execution_sheet_detail_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoExecutionDashboard extends StatefulWidget {
  final String jwtToken;
  final String username;

  const PoExecutionDashboard({
    super.key,
    required this.jwtToken,
    required this.username,
  });

  @override
  State<PoExecutionDashboard> createState() => _PoExecutionDashboardState();
}

class _PoExecutionDashboardState extends State<PoExecutionDashboard> {
  List<ExecutionSheet> _allSheets = [];
  List<ExecutionSheet> _filteredSheets = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';
  bool _showOnlyAssigned = false;

  final Map<String, String> _filterOptions = {
    'all': 'All Sheets',
    'PENDING': 'Pending',
    'IN_PROGRESS': 'In Progress',
    'COMPLETED': 'Completed',
  };

  @override
  void initState() {
    super.initState();
    _loadExecutionSheets();
  }

  Future<void> _loadExecutionSheets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sheets = await ExecutionService.fetchExecutionSheets(
        jwtToken: widget.jwtToken,
        statusFilter: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      // Check assignments for each sheet
      List<ExecutionSheet> sheetsWithAssignments = [];
      for (var sheet in sheets) {
        try {
          final details = await ExecutionService.fetchExecutionSheetDetails(
            sheetId: sheet.id,
            jwtToken: widget.jwtToken,
          );

          // Check if user has any assigned parcels
          bool hasAssignedParcels = _checkUserAssignments(details);
          sheet.isAssignedToCurrentUser = hasAssignedParcels;
          sheetsWithAssignments.add(sheet);
        } catch (e) {
          // If we can't check assignments, still add the sheet
          sheetsWithAssignments.add(sheet);
        }
      }

      setState(() {
        _allSheets = sheetsWithAssignments;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _checkUserAssignments(Map<String, dynamic> details) {
    final List<dynamic> operations = details['operations'] ?? [];

    for (var opData in operations) {
      final List<dynamic> parcels = opData['parcels'] ?? [];
      for (var parcelData in parcels) {
        final parcelExecution = parcelData['parcelExecution'];
        if (parcelExecution != null &&
            parcelExecution['assignedUsername'] == widget.username) {
          return true;
        }
      }
    }
    return false;
  }

  void _applyFilters() {
    _filteredSheets = _allSheets.where((sheet) {
      if (_showOnlyAssigned && !sheet.isAssignedToCurrentUser) {
        return false;
      }
      return true;
    }).toList();
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null) {
      setState(() {
        _selectedFilter = newFilter;
      });
      _loadExecutionSheets();
    }
  }

  void _onAssignedFilterChanged(bool? value) {
    setState(() {
      _showOnlyAssigned = value ?? false;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Execution Sheets'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadExecutionSheets,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFilter,
                        decoration: const InputDecoration(
                          labelText: 'Filter by Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: _filterOptions.entries.map((entry) {
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: _onFilterChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Show only my assigned sheets'),
                  value: _showOnlyAssigned,
                  onChanged: _onAssignedFilterChanged,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Error loading execution sheets',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadExecutionSheets,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_filteredSheets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _showOnlyAssigned
                  ? 'No assigned execution sheets found'
                  : 'No execution sheets found',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              _showOnlyAssigned
                  ? 'You don\'t have any assigned activities in the current filter'
                  : 'Try changing the filter or refresh the list',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExecutionSheets,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _filteredSheets.length,
        itemBuilder: (context, index) {
          final sheet = _filteredSheets[index];
          return _buildExecutionSheetCard(sheet);
        },
      ),
    );
  }

  Widget _buildExecutionSheetCard(ExecutionSheet sheet) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PoExecutionSheetDetailsScreen(
                sheet: sheet,
                jwtToken: widget.jwtToken,
                username: widget.username,
              ),
            ),
          ).then((_) => _loadExecutionSheets());
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sheet.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  _buildStatusChip(sheet.state),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Work Sheet: ${sheet.associatedWorkSheetId}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Assigned to: ${sheet.associatedUser}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              if (sheet.isAssignedToCurrentUser) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'You have assigned parcels',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to view details',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toUpperCase()) {
      case 'PENDING':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'IN_PROGRESS':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case 'COMPLETED':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
