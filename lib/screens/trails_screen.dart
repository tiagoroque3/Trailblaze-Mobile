import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/trail.dart';
import '../services/trail_service.dart';
import '../utils/app_constants.dart';
import 'create_trail_screen.dart';
import 'trail_detail_screen.dart';

class TrailsScreen extends StatefulWidget {
  final String username;
  final String jwtToken;
  final List<String>? userRoles;

  const TrailsScreen({
    super.key,
    required this.username,
    required this.jwtToken,
    this.userRoles,
  });

  @override
  State<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends State<TrailsScreen> {
  bool _isLoading = false;
  List<Trail> _allTrails = [];
  List<Trail> _filteredTrails = [];
  String _selectedFilter = 'all';

  final Map<String, String> _filterOptions = {
    'all': 'All Trails',
    'my': 'My Trails',
    'public': 'Public Trails',
    'private': 'Private Trails',
  };

  @override
  void initState() {
    super.initState();
    _loadTrails();
  }

  Future<void> _loadTrails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final trails = await TrailService.getAllTrails(jwtToken: widget.jwtToken);
      setState(() {
        _allTrails = trails;
        _applyFilter();
      });
    } catch (e) {
      _showSnackBar('Error loading trails: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    switch (_selectedFilter) {
      case 'my':
        _filteredTrails = _allTrails
            .where((trail) => trail.createdBy == widget.username)
            .toList();
        break;
      case 'public':
        _filteredTrails = _allTrails
            .where((trail) => trail.visibility == TrailVisibility.PUBLIC)
            .toList();
        break;
      case 'private':
        _filteredTrails = _allTrails
            .where((trail) => 
                trail.visibility == TrailVisibility.PRIVATE && 
                trail.createdBy == widget.username)
            .toList();
        break;
      default:
        _filteredTrails = _allTrails;
    }
    
    // Sort by creation date (newest first)
    _filteredTrails.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null) {
      setState(() {
        _selectedFilter = newFilter;
        _applyFilter();
      });
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _deleteTrail(Trail trail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trail'),
        content: Text('Are you sure you want to delete "${trail.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await TrailService.deleteTrail(
          jwtToken: widget.jwtToken,
          trailId: trail.id,
        );
        _showSnackBar('Trail deleted successfully');
        _loadTrails();
      } catch (e) {
        _showSnackBar('Error deleting trail: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has RU role
    final bool hasRURole = widget.userRoles?.contains('RU') == true;

    if (!hasRURole) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: AppColors.primaryGreen,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 20),
              const Text(
                'You need the "RU" role to access trails.',
                style: TextStyle(fontSize: 18, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trails'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTrails,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter controls
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
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter Trails',
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
          ),

          // Trails list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTrails.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadTrails,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _filteredTrails.length,
                          itemBuilder: (context, index) {
                            return _buildTrailCard(_filteredTrails[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateTrailScreen(
                username: widget.username,
                jwtToken: widget.jwtToken,
              ),
            ),
          ).then((_) => _loadTrails());
        },
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Create New Trail',
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    String description;

    switch (_selectedFilter) {
      case 'my':
        message = 'No trails created yet';
        description = 'Create your first trail to get started';
        break;
      case 'public':
        message = 'No public trails available';
        description = 'Public trails will appear here when created';
        break;
      case 'private':
        message = 'No private trails';
        description = 'Your private trails will appear here';
        break;
      default:
        message = 'No trails available';
        description = 'Create your first trail or check back later';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrailCard(Trail trail) {
    final isMyTrail = trail.createdBy == widget.username;

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
              builder: (context) => TrailDetailScreen(
                trail: trail,
                jwtToken: widget.jwtToken,
                username: widget.username,
              ),
            ),
          ).then((_) => _loadTrails());
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
                      trail.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                  _buildVisibilityChip(trail.visibility),
                  if (isMyTrail) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteTrail(trail);
                        }
                      },
                      itemBuilder: (context) => [
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
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Created by ${trail.createdBy}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                'Created on ${DateFormat('MMM dd, yyyy').format(trail.createdAt)}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              if (trail.worksheetId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Associated with Worksheet ${trail.worksheetId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      'Distance',
                      trail.formattedDistance,
                      Icons.straighten,
                    ),
                    _buildStatColumn(
                      'Duration',
                      trail.formattedDuration,
                      Icons.timer,
                    ),
                    _buildStatColumn(
                      'Points',
                      '${trail.points.length}',
                      Icons.location_on,
                    ),
                    _buildStatColumn(
                      'Notes',
                      '${trail.observations.length}',
                      Icons.note,
                    ),
                  ],
                ),
              ),
              if (trail.visibility == TrailVisibility.PRIVATE && 
                  trail.status != null && 
                  isMyTrail) ...[
                const SizedBox(height: 8),
                _buildStatusChip(trail.status!),
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

  Widget _buildVisibilityChip(TrailVisibility visibility) {
    final isPublic = visibility == TrailVisibility.PUBLIC;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublic ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPublic ? Icons.public : Icons.lock,
            size: 12,
            color: isPublic ? Colors.green.shade800 : Colors.orange.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            isPublic ? 'Public' : 'Private',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isPublic ? Colors.green.shade800 : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(TrailStatus status) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case TrailStatus.ACTIVE:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        icon = Icons.play_circle;
        break;
      case TrailStatus.COMPLETED:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
      case TrailStatus.PAUSED:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.pause_circle;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.name.toLowerCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryGreen,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}