import 'package:flutter/material.dart';
import 'package:trailblaze_app/models/trail.dart';
import 'package:trailblaze_app/services/trail_service.dart';
import 'package:trailblaze_app/screens/trail_recording_screen.dart';
import 'package:trailblaze_app/screens/trail_details_screen.dart';
import 'package:trailblaze_app/utils/app_constants.dart';

class TrailsScreen extends StatefulWidget {
  final String username;
  final String jwtToken;
  final List<String> userRoles;

  const TrailsScreen({
    super.key,
    required this.username,
    required this.jwtToken,
    required this.userRoles,
  });

  @override
  State<TrailsScreen> createState() => _TrailsScreenState();
}

class _TrailsScreenState extends State<TrailsScreen> {
  List<Trail> _trails = [];
  bool _isLoading = true;
  String? _error;
  String _selectedFilter = 'all';

  final Map<String, String> _filterOptions = {
    'all': 'All Trails',
    'my': 'My Trails',
    'public': 'Public Trails',
  };

  @override
  void initState() {
    super.initState();
    _loadTrails();
  }

  bool get _hasAccess {
    return widget.userRoles.contains('RU') || widget.userRoles.contains('SYSADMIN');
  }

  Future<void> _loadTrails() async {
    if (!_hasAccess) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final trails = await TrailService.fetchTrails(jwtToken: widget.jwtToken);
      setState(() {
        _trails = trails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Trail> get _filteredTrails {
    switch (_selectedFilter) {
      case 'my':
        return _trails.where((trail) => trail.createdBy == widget.username).toList();
      case 'public':
        return _trails.where((trail) => trail.visibility == TrailVisibility.PUBLIC).toList();
      default:
        return _trails;
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

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: AppColors.primaryGreen,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 80,
                color: Colors.grey,
              ),
              SizedBox(height: 20),
              Text(
                'You need RU or SYSADMIN role to access trails.',
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
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedFilter = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(child: _buildContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrailRecordingScreen(
                username: widget.username,
                jwtToken: widget.jwtToken,
              ),
            ),
          ).then((_) => _loadTrails());
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('New Trail'),
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
              'Error loading trails',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTrails,
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

    final filteredTrails = _filteredTrails;

    if (filteredTrails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No trails found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first trail by tapping the + button',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTrails,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: filteredTrails.length,
        itemBuilder: (context, index) {
          final trail = filteredTrails[index];
          return _buildTrailCard(trail);
        },
      ),
    );
  }

  Widget _buildTrailCard(Trail trail) {
    final isOwner = trail.createdBy == widget.username;
    final distance = trail.totalDistance;

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
              builder: (context) => TrailDetailsScreen(
                trail: trail,
                username: widget.username,
                jwtToken: widget.jwtToken,
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
                  _buildStatusChip(trail),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOwner ? 'You' : trail.createdBy,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontWeight: isOwner ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trail.formattedDate,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.route,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${trail.points.length} points',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.straighten,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    distance > 1000
                        ? '${(distance / 1000).toStringAsFixed(2)} km'
                        : '${distance.toStringAsFixed(0)} m',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              if (trail.observations.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.comment,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${trail.observations.length} observation${trail.observations.length == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
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

  Widget _buildStatusChip(Trail trail) {
    Color backgroundColor;
    Color textColor;
    String text;

    if (trail.visibility == TrailVisibility.PUBLIC) {
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade800;
      text = 'Public';
    } else {
      switch (trail.status) {
        case TrailStatus.ACTIVE:
          backgroundColor = Colors.blue.shade100;
          textColor = Colors.blue.shade800;
          text = 'Active';
          break;
        case TrailStatus.COMPLETED:
          backgroundColor = Colors.orange.shade100;
          textColor = Colors.orange.shade800;
          text = 'Completed';
          break;
        default:
          backgroundColor = Colors.grey.shade100;
          textColor = Colors.grey.shade800;
          text = 'Private';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}