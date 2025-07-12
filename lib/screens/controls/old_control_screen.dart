import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RobotControlScreen extends StatefulWidget {
  const RobotControlScreen({super.key});

  @override
  RobotControlScreenState createState() => RobotControlScreenState();
}

class RobotControlScreenState extends State<RobotControlScreen> {
  bool isManualMode = false;
  double speed = 10.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Robot Control'),
        backgroundColor: Colors.blue,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              //mode selection
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control Mode',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      SwitchListTile(
                        title: Text('Manual Control'),
                        subtitle: Text(
                          isManualMode
                              ? 'Manual Navigation enabled'
                              : 'Autonomous mode active',
                        ),
                        value: isManualMode,
                        onChanged: (value) {
                          setState(() => isManualMode = value);
                          _sendControlMode(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Speed Control
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Speed Control',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Slider(
                        value: speed,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${speed.round()}%',
                        onChanged: (value) {
                          setState(() => speed = value);
                          _sendSpeedControl(value);
                        },
                      ),
                      Text('Current Speed: ${speed.round()}%'),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Manual Navigation Controls
              if (isManualMode) ...[
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Manual Navigation',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 20),

                        // Direction Controls
                        Column(
                          children: [
                            // Forward
                            GestureDetector(
                              onTapDown: (_) => _sendDirection('forward'),
                              onTapUp: (_) => _sendDirection('stop'),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_up,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),

                            SizedBox(height: 20),

                            // Left, Stop, Right
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                GestureDetector(
                                  onTapDown: (_) => _sendDirection('left'),
                                  onTapUp: (_) => _sendDirection('stop'),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.keyboard_arrow_left,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),

                                GestureDetector(
                                  onTap: () => _sendDirection('stop'),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.stop,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),

                                GestureDetector(
                                  onTapDown: (_) => _sendDirection('right'),
                                  onTapUp: (_) => _sendDirection('stop'),
                                  child: Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.blue,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.keyboard_arrow_right,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 20),

                            // Backward
                            GestureDetector(
                              onTapDown: (_) => _sendDirection('backward'),
                              onTapUp: (_) => _sendDirection('stop'),
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Arm Controls
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mechanical Arm Controls',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _sendArmCommand('activate'),
                                icon: Icon(Icons.build),
                                label: Text(
                                  'Activate Weeding',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _sendArmCommand('retract'),
                                icon: Icon(Icons.back_hand),
                                label: Text(
                                  'Retract Arm',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
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
            ],
          ),
        ),
      ),
    );
  }

  void _sendControlMode(bool manual) async {
    try {
      await http.post(
        Uri.parse('http://192.168.1.100:5000/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'mode': manual ? 'manual' : 'autonomous'}),
      );
    } catch (e) {
      debugPrint('Error sending control mode: $e');
    }
  }

  void _sendSpeedControl(double speed) async {
    try {
      await http.post(
        Uri.parse('http://192.168.1.100:5000/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'speed': speed.round()}),
      );
    } catch (e) {
      debugPrint('Error sending speed control: $e');
    }
  }

  void _sendDirection(String direction) async {
    try {
      await http.post(
        Uri.parse('http://192.168.1.100:5000/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'direction': direction}),
      );
    } catch (e) {
      debugPrint('Error sending direction: $e');
    }
  }

  void _sendArmCommand(String command) async {
    try {
      await http.post(
        Uri.parse('http://192.168.1.100:5000/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'arm_action': command}),
      );
    } catch (e) {
      debugPrint('Error sending arm command: $e');
    }
  }
}
