import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/execution_sheet.dart';
import 'package:trailblaze_app/models/operation_execution.dart';
import 'package:trailblaze_app/models/parcel_operation_execution.dart';
import 'package:trailblaze_app/services/execution_sheet_service.dart';
import 'package:trailblaze_app/screens/po_parcel_operation_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class PoExecutionSheetDetailsScreen extends StatefulWidget {
  final ExecutionSheet sheet;
  final String jwtToken;
  final String username;

  const PoExecutionSheetDetailsScreen({
    super.key,
    required this.sheet,
    required this.jwtToken,
    required this.username,
  });

  @override
  State<PoExecutionSheetDetailsScreen> createState() => _PoExecutionSheetDetailsScreenState();
}

class _PoExecutionSheetDetailsScreenState extends State<PoExecutionSheetDetailsScreen> {
  List<OperationExecution> _operations = [];
  List<ParcelOperationExecution> _userAssignedParcels = [];
  bool _isLoading = false;
  bool _showOnlyMyParcels = true;

  @override
  void initState() {
    super.initState();
    _loadSheetDetails();
  }

  Future<void> _loadSheetDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ExecutionSheetService.fetchExecutionSheetDetails(
        sheetId: widget.sheet.id,
        jwtToken: widget.jwtToken,
      );

      final operations = result['operations'] as List<OperationExecution>;
      
      // Filter parcels assigned to current user
      List<ParcelOperationExecution> userParcels = [];
      for (var operation in operations) {
        for (var parcel in operation.parcels) {
          // Check if user has activities in this parcel
          bool hasUserActivities = parcel.activities.any(
            (activity) => activity.operatorId == widget.username
          );
          
          if (hasUserActivities) {
            userParcels.add(parcel);
          }
        }
      }

      setState(() {
        _operations = operations;
        _userAssignedParcels = userParcels;
      });
    } catch (e) {
      _showErrorSnackBar('Error loading sheet details: $e');
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

  Widget _buildSheetHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.sheet.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${widget.sheet.state}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Progress: ${widget.sheet.percentExecuted.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: widget.sheet.percentExecuted / 100,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Show only my assigned parcels',
            style: TextStyle(fontSize: 16),
          ),
          Switch(
            value: _showOnlyMyParcels,
            onChanged: (value) {
              setState(() {
                _showOnlyMyParcels = value;
              });
            },
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildOperationCard(OperationExecution operation) {
    final parcelsToShow = _showOnlyMyParcels
        ? operation.parcels.where((parcel) =>
            parcel.activities.any((activity) => activity.operatorId == widget.username))
        : operation.parcels;

    if (_showOnlyMyParcels && parcelsToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text(
          operation.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        subtitle: Text(
          '${operation.statusText} • ${parcelsToShow.length} parcels',
        ),
        children: parcelsToShow.map((parcel) => _buildParcelTile(parcel)).toList(),
      ),
    );
  }

  Widget _buildParcelTile(ParcelOperationExecution parcel) {
    final hasOngoingActivity = parcel.hasOngoingActivity;
    final canStartActivity = parcel.canStartActivity;

    return ListTile(
      title: Text(parcel.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status: ${parcel.statusDisplayText}'),
          if (hasOngoingActivity)
            Text(
              'Activity in progress',
              style: TextStyle(
                color: Colors.orange[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          Text('Activities: ${parcel.activities.length}'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasOngoingActivity)
            Icon(
              Icons.play_circle_filled,
              color: Colors.orange[700],
            )
          else if (canStartActivity)
            Icon(
              Icons.play_circle_outline,
              color: AppColors.primaryGreen,
            ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PoParcelOperationDetailsScreen(
              parcelOperation: parcel,
              jwtToken: widget.jwtToken,
              username: widget.username,
            ),
          ),
        ).then((_) => _loadSheetDetails());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Execution Sheet'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSheetDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryGreen,
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildSheetHeader(),
                ),
                _buildFilterToggle(),
                Expanded(
                  child: _operations.isEmpty
                      ? const Center(
                          child: Text(
                            'No operations found',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _operations.length,
                          itemBuilder: (context, index) {
                            return _buildOperationCard(_operations[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}