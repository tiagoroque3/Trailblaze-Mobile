import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/services/execution_sheet_service.dart';
import 'package:trailblaze_app/screens/po_execution_sheet_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoExecutionSheetsView extends StatefulWidget {
  final String jwtToken;
  final String username;

  const PoExecutionSheetsView({
    super.key,
    required this.jwtToken,
    required this.username,
  });

  @override
  State<PoExecutionSheetsView> createState() => _PoExecutionSheetsViewState();
}

class _PoExecutionSheetsViewState extends State<PoExecutionSheetsView> {
  List<ExecutionSheet> _executionSheets = [];
  bool _isLoading = false;
  String? _selectedStatus;
  bool _showOnlyAssigned = true;

  final List<String> _statusOptions = [
    'All',
    'PENDING',
    'IN_PROGRESS',
    'COMPLETED',
    'CANCELLED'
  ];

  @override
  void initState() {
    super.initState();
    _loadExecutionSheets();
  }

  Future<void> _loadExecutionSheets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sheets = await ExecutionSheetService.fetchExecutionSheets(
        jwtToken: widget.jwtToken,
        statusFilter: _selectedStatus == 'All' ? null : _selectedStatus,
      );

      // Filter sheets based on user assignments
      List<ExecutionSheet> filteredSheets = sheets;
      if (_showOnlyAssigned) {
        // This would need to be implemented based on your backend logic
        // For now, we'll show all sheets but you can add filtering logic here
        filteredSheets = sheets.where((sheet) {
          // Add logic to check if the sheet has operations assigned to current user
          return true; // Placeholder
        }).toList();
      }

      setState(() {
        _executionSheets = filteredSheets;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading execution sheets: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _selectedStatus ?? 'All',
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: _statusOptions.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value == 'All' ? null : value;
                });
                _loadExecutionSheets();
              },
            ),
          ),
          const SizedBox(width: 16),
          FilterChip(
            label: const Text('Only Assigned'),
            selected: _showOnlyAssigned,
            onSelected: (selected) {
              setState(() {
                _showOnlyAssigned = selected;
              });
              _loadExecutionSheets();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionSheetCard(ExecutionSheet sheet) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                'Associated User: ${sheet.associatedUser}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Progress: ${sheet.percentExecuted.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: sheet.percentExecuted / 100,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Worksheet: ${sheet.associatedWorkSheetId}',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.primaryGreen,
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
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[800]!;
        break;
      case 'IN_PROGRESS':
        backgroundColor = Colors.blue[100]!;
        textColor = Colors.blue[800]!;
        break;
      case 'COMPLETED':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[800]!;
        break;
      case 'CANCELLED':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[800]!;
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[800]!;
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
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildStatusFilter(),
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                )
              : _executionSheets.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.assignment,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No execution sheets found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Check your filters or contact your supervisor',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadExecutionSheets,
                      child: ListView.builder(
                        itemCount: _executionSheets.length,
                        itemBuilder: (context, index) {
                          return _buildExecutionSheetCard(_executionSheets[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}