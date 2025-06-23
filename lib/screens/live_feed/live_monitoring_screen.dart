import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class LiveMonitoringScreen extends StatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  _LiveMonitoringScreenState createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  final String streamUrl = 'http://192.168.1.100:5000/stream';
  bool isEmergencyStop = false;
  String robotStatus = 'Active';
  String currentTask = 'Scanning for weeds';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Live Monitoring'),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          Container(
            margin: EdgeInsets.all(8),
            child: Chip(
              label: Text(robotStatus),
              backgroundColor: robotStatus == 'Active'
                  ? Colors.green[100]
                  : Colors.red[100],
              avatar: CircleAvatar(
                backgroundColor: robotStatus == 'Active'
                    ? Colors.green
                    : Colors.red,
                radius: 6,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live video feed
          Expanded(
            flex: 3,
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam, size: 64, color: Colors.white54),
                        SizedBox(height: 16),
                        Text(
                          'Live Camera Feed',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        Text(
                          streamUrl,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Status Cards
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  // Current Task Card
                  Card(
                    elevation: 4,
                    child: ListTile(
                      leading: Icon(Icons.task_alt, color: Colors.blue),
                      title: Text('Current Task'),
                      subtitle: Text(currentTask),
                      trailing: Icon(Icons.refresh),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Emergency Controls
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _toggleEmergencyStop(),
                          icon: Icon(Icons.stop),
                          label: Text(
                            isEmergencyStop ? 'Resume' : 'Emergency Stop',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEmergencyStop
                                ? Colors.green
                                : Colors.red,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _returnToBase(),
                          icon: Icon(Icons.home),
                          label: Text(
                            'Return to Base',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleEmergencyStop() async {
    setState(() {
      isEmergencyStop = !isEmergencyStop;
      robotStatus = isEmergencyStop ? 'Stopped' : 'Active';
      currentTask = isEmergencyStop ? 'None' : currentTask;
    });

    // end control command to robot
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.100:5000/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': isEmergencyStop ? 'stop' : 'resume'}),
      );
    } catch (e) {
      debugPrint('Error sending control command: $e');
    }
  }

  void _returnToBase() async {
    setState(() {
      currentTask = 'Returning to base station';
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.100:5000/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'return_home'}),
      );
    } catch (e) {
      debugPrint('Error sending return home command: $e');
    }
  }
}
