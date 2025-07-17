import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/event_service.dart';

class EventsScreen extends StatefulWidget {
  final String username;
  final String jwtToken;
  final List<String>? userRoles;

  const EventsScreen({
    super.key,
    required this.username,
    required this.jwtToken,
    this.userRoles,
  });

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  bool _isLoading = false;
  List<Event> _allEvents = [];
  List<Event> _myEvents = [];
  bool _showingAllEvents = true;
  Set<String> _registeredEventIds = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all events
      final allEvents = await EventService.fetchAllEvents(jwtToken: widget.jwtToken);
      // Load user's registered events
      final myEvents = await EventService.fetchMyEvents(jwtToken: widget.jwtToken);

      setState(() {
        _allEvents = allEvents;
        _myEvents = myEvents;
        _registeredEventIds = myEvents.map((e) => e.id).toSet();
      });
    } catch (e) {
      _showSnackBar('Error loading events: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerForEvent(Event event) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await EventService.registerForEvent(
        eventId: event.id,
        jwtToken: widget.jwtToken,
      );

      if (success) {
        _showSnackBar('Successfully registered for ${event.title}');
        await _loadEvents();
      } else {
        _showSnackBar('Failed to register for event', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error registering for event: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unregisterFromEvent(Event event) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final success = await EventService.unregisterFromEvent(
        eventId: event.id,
        jwtToken: widget.jwtToken,
      );

      if (success) {
        _showSnackBar('Successfully unregistered from ${event.title}');
        await _loadEvents();
      } else {
        _showSnackBar('Failed to unregister from event', isError: true);
      }
    } catch (e) {
      _showSnackBar('Error unregistering from event: $e', isError: true);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showUnregisterDialog(Event event) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Unregister'),
          content: Text(
            'Are you sure you want to unregister from "${event.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _unregisterFromEvent(event);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Unregister'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    final isRegistered = _registeredEventIds.contains(event.id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.formattedDateTime,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              event.formattedLocation,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              event.description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            if (_showingAllEvents && !isRegistered)
              ElevatedButton(
                onPressed: _isLoading ? null : () => _registerForEvent(event),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F695B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Register'),
              )
            else if (_showingAllEvents && isRegistered)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Registered',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (!_showingAllEvents)
              ElevatedButton(
                onPressed: _isLoading ? null : () => _showUnregisterDialog(event),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text('Unregister'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if user has RU role
    final bool hasRURole = widget.userRoles?.contains('RU') == true;

    if (!hasRURole) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
          backgroundColor: const Color(0xFF4F695B),
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
                'You need the "RU" role to access events.',
                style: TextStyle(fontSize: 18, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final eventsToShow = _showingAllEvents ? _allEvents : _myEvents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: const Color(0xFF4F695B),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showingAllEvents = true; 
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showingAllEvents 
                          ? const Color(0xFF4F695B) 
                          : Colors.grey.shade300,
                      foregroundColor: _showingAllEvents 
                          ? Colors.white 
                          : Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('All Events'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showingAllEvents = false; 
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showingAllEvents 
                          ? const Color(0xFF4F695B) 
                          : Colors.grey.shade300,
                      foregroundColor: !_showingAllEvents 
                          ? Colors.white 
                          : Colors.black54,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('My Events'),
                  ),
                ),
              ],
            ),
          ),
          // Events list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : eventsToShow.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showingAllEvents ? Icons.event : Icons.event_available,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showingAllEvents ? 'No events available' : 'No registered events',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            if (!_showingAllEvents) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Register for events in the "All Events" tab',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: eventsToShow.length,
                        itemBuilder: (context, index) {
                          return _buildEventCard(eventsToShow[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
