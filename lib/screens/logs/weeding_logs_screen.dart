import 'package:flutter/material.dart';
//import 'package:robo_app/utils/colors.dart';

class WeedingLogsScreen extends StatefulWidget {
  const WeedingLogsScreen({super.key});

  @override
  WeedingLogsScreenState createState() => WeedingLogsScreenState();
}

class WeedingLogsScreenState extends State<WeedingLogsScreen> {
  List<Map<String, dynamic>> weedingLogs = [
    {
      'timestamp': '2025-06-23 14:30:15',
      'action': 'Weed Detected',
      'location': 'Row 2, Position 45m',
      'confidence': 0.92,
      'status': 'Removed',
    },
    {
      'timestamp': '2025-06-23 14:28:42',
      'action': 'Weed Detected',
      'location': 'Row 2, Position 43m',
      'confidence': 0.87,
      'status': 'Removed',
    },
    {
      'timestamp': '2025-06-23 14:25:10',
      'action': 'Row Completed',
      'location': 'Row 1',
      'confidence': null,
      'status': 'Complete',
    },
    {
      'timestamp': '2025-06-23 14:20:33',
      'action': 'Weed Detected',
      'location': 'Row 1, Position 78m',
      'confidence': 0.95,
      'status': 'Removed',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Weeding Logs'),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: Icon(Icons.download), onPressed: _exportLogs),
        ],
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: weedingLogs.length,
        itemBuilder: (context, index) {
          final log = weedingLogs[index];
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(log['status']),
                child: Icon(_getStatusIcon(log['action']), color: Colors.white),
              ),
              title: Text(log['action']),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(log['location']),
                  Text(
                    log['timestamp'],
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (log['confidence'] != null)
                    Text(
                      'Confidence: ${(log['confidence'] * 100).round()}%',
                      style: TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                ],
              ),
              trailing: Chip(
                label: Text(log['status']),
                backgroundColor: _getStatusColor(
                  log['status'],
                ).withOpacity(0.2),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _clearLogs,
        backgroundColor: Colors.red,
        tooltip: 'Clear All Logs',
        child: Icon(Icons.clear_all),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'removed':
        return Colors.green;
      case 'complete':
        return Colors.blue;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String action) {
    switch (action.toLowerCase()) {
      case 'weed detected':
        return Icons.grass;
      case 'row completed':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  void _exportLogs() {
    // Export logs functionality
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Logs exported successfully!')));
  }

  void _clearLogs() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Clear All Logs'),
          content: Text('Are you sure you want to clear all weeding logs?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Clear'),
              onPressed: () {
                setState(() {
                  weedingLogs.clear();
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('All logs cleared successfully!')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
