import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/services/prbo_execution_service.dart';
import 'package:trailblaze_app/screens/prbo_execution_sheet_detail_screen.dart';
import 'package:trailblaze_app/screens/prbo_create_execution_sheet_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PrboExecutionDashboard extends StatefulWidget {
  final String jwtToken;
  final String username;

  const PrboExecutionDashboard({
    super.key,
    required this.jwtToken,
    required this.username,
  });

  @override
  State<PrboExecutionDashboard> createState() => _PrboExecutionDashboardState();
}

class _PrboExecutionDashboardState extends State<PrboExecutionDashboard> {
  List<ExecutionSheet> _allSheets = [];
  List<ExecutionSheet> _filteredSheets = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

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
      // PRBO can see all execution sheets, not just assigned ones
      final sheets = await PrboExecutionService.fetchAllExecutionSheets(
        jwtToken: widget.jwtToken,
        statusFilter: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      setState(() {
        _allSheets = sheets;
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

  void _applyFilters() {
    _filteredSheets = _allSheets;
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null) {
      setState(() {
        _selectedFilter = newFilter;
      });
      _loadExecutionSheets();
    }
  }

  void _showCreateSheet() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrboCreateExecutionSheetScreen(
          jwtToken: widget.jwtToken,
          username: widget.username,
        ),
      ),
    ).then((_) => _loadExecutionSheets());
  }

  Future<void> _deleteExecutionSheet(ExecutionSheet sheet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Execution Sheet'),
        content: Text(
          'Are you sure you want to delete "${sheet.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PrboExecutionService.deleteExecutionSheet(
          sheetId: sheet.id,
          jwtToken: widget.jwtToken,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Execution sheet "${sheet.title}" deleted successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );

        _loadExecutionSheets();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete execution sheet: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execution Sheets Management'),
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
              ],
            ),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        backgroundColor: AppColors.primaryGreen,
        tooltip: 'Create New Execution Sheet',
        child: const Icon(Icons.add, color: Colors.white),
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
              'No execution sheets found',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the filter or create your first execution sheet',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _showCreateSheet,
              icon: const Icon(Icons.add),
              label: const Text('Create Execution Sheet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
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
              builder: (context) => PrboExecutionSheetDetailsScreen(
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
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                PrboCreateExecutionSheetScreen(
                                  jwtToken: widget.jwtToken,
                                  username: widget.username,
                                  editingSheet: sheet,
                                ),
                          ),
                        ).then((_) => _loadExecutionSheets());
                      } else if (value == 'delete') {
                        _deleteExecutionSheet(sheet);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    child: const Icon(Icons.more_vert, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Work Sheet ID: ${sheet.associatedWorkSheetId}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Associated User: ${sheet.associatedUser}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              if (sheet.associatedUser == widget.username) ...[
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
                    'Assigned to me',
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
