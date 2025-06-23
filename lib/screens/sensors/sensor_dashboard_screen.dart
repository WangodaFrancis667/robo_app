import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class SensorDashboardScreen extends StatefulWidget {
  const SensorDashboardScreen({super.key});

  @override
  SensorDashboardScreenState createState() => SensorDashboardScreenState();
}

class SensorDashboardScreenState extends State<SensorDashboardScreen> {
  Timer? _timer;
  Map<String, dynamic> sensorData = {
    'battery_level': 85,
    'battery_voltage': 11.8,
    'temperature': 32,
    'left_distance': 45,
    'right_distance': 38,
    'front_distance': 120,
    'solar_power': 15.2,
    'current_draw': 2.3,
    'uptime': '02:34:15',
  };

  @override
  void initState() {
    super.initState();
    _startPeriodicUpdate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPeriodicUpdate() {
    _timer = Timer.periodic(Duration(seconds: 2), (timer) {
      _fetchSensorData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sensor Dashboard'),
        backgroundColor: Colors.purple,
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _fetchSensorData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSensorData,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Battery Status
            _buildBatteryCard(),
            SizedBox(height: 16),

            // Distance Sensors
            _buildDistanceSensorsCard(),
            SizedBox(height: 16),

            // System Status
            _buildSystemStatusCard(),
            SizedBox(height: 16),

            // Power Management
            _buildPowerManagementCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryCard() {
    //final batteryLevel = sensorData['battery_level'] ?? 0;
    //final batteryVoltage = sensorData['battery_voltage'] ?? 0.0;

    final batteryLevel = _ensureInt(sensorData['battery_level'], 85);
    final batteryVoltage = _ensureDouble(sensorData['battery_voltage'], 11.8);

    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.battery_full,
                  color: _getBatteryColor(batteryLevel),
                  size: 28,
                ),
                SizedBox(width: 8),
                Text(
                  'Battery Status',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: 16),

            // Battery Level Indicator
            Row(
              children: [
                Text('Level: '),
                Expanded(
                  child: LinearProgressIndicator(
                    value: batteryLevel / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getBatteryColor(batteryLevel),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text('$batteryLevel%'),
              ],
            ),

            SizedBox(height: 8),
            Text('Voltage: ${batteryVoltage}V'),

            if (batteryLevel < 20)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Low battery warning!',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceSensorsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.radar, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Text(
                  'Distance Sensors',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildDistanceIndicator(
                    'Left',
                    // sensorData['left_distance'] ?? 0,
                    sensorData['left_distance'],
                    Icons.arrow_back,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildDistanceIndicator(
                    'Front',
                    //sensorData['front_distance'] ?? 0,
                    sensorData['front_distance'],
                    Icons.arrow_upward,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildDistanceIndicator(
                    'Right',
                    // sensorData['right_distance'] ?? 0,
                    sensorData['right_distance'],
                    Icons.arrow_forward,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceIndicator(String label, dynamic distance, IconData icon) {
    // Convert to integer to avoid type errors
    int distanceInt = (distance is double) ? distance.round() : (distance ?? 0);
    Color color = distanceInt < 20
        ? Colors.red
        : distanceInt < 50
        ? Colors.orange
        : Colors.green;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          Text(
            '${distanceInt}cm',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStatusCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.computer, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text(
                  'System Status',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: 16),

            ListTile(
              leading: Icon(Icons.thermostat, color: Colors.orange),
              title: Text('Temperature'),
              trailing: Text('${_ensureInt(sensorData['temperature'], 32)}°C'),
            ),

            ListTile(
              leading: Icon(Icons.timer, color: Colors.blue),
              title: Text('Uptime'),
              trailing: Text('${sensorData['uptime']}'),
            ),

            ListTile(
              leading: Icon(Icons.electrical_services, color: Colors.purple),
              title: Text('Current Draw'),
              trailing: Text('${_ensureDouble(sensorData['current_draw'], 2.3).toStringAsFixed(1)}A'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerManagementCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.solar_power, color: Colors.amber, size: 28),
                SizedBox(width: 8),
                Text(
                  'Power Management',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            SizedBox(height: 16),

            ListTile(
              leading: Icon(Icons.wb_sunny, color: Colors.amber),
              title: Text('Solar Input'),
              trailing: Text('${_ensureDouble(sensorData['solar_power'], 15.2).toStringAsFixed(1)}W'),
            ),

            Row(
              children: [
                Text('Solar Status: '),
                Expanded(
                  child: LinearProgressIndicator(
                    value:
                        _ensureDouble(sensorData['solar_power'], 15.2) / 20, // Max 20W panel
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  '${((_ensureDouble(sensorData['solar_power'], 15.2) / 20 * 100).round())}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 50) return Colors.green;
    if (level > 20) return Colors.orange;
    return Colors.red;
  }

  Future<void> _fetchSensorData() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.100:5000/status'),
        // Add timeout to prevent long waiting periods
        ).timeout(Duration(seconds: 5));
        
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Ensure all values have the correct type
        setState(() {
          sensorData = {
            'battery_level': _ensureInt(data['battery_level'], 85),
            'battery_voltage': _ensureDouble(data['battery_voltage'], 11.8),
            'temperature': _ensureInt(data['temperature'], 32),
            'left_distance': _ensureInt(data['left_distance'], 45),
            'right_distance': _ensureInt(data['right_distance'], 38),
            'front_distance': _ensureInt(data['front_distance'], 120),
            'solar_power': _ensureDouble(data['solar_power'], 15.2),
            'current_draw': _ensureDouble(data['current_draw'], 2.3),
            'uptime': data['uptime'] ?? '02:34:15',
          };
        });
      } else {
        _updateSimulatedData();
      }
    } catch (e) {
      print('Error fetching sensor data: $e');
      _updateSimulatedData();
    }
  }
  
  // Helper method to update simulated data
  void _updateSimulatedData() {
    setState(() {
      // Generate more realistic changes to the data
      final random = DateTime.now().millisecondsSinceEpoch % 100 / 100;
      
      sensorData['battery_level'] = _ensureInt(
          (sensorData['battery_level'] as num) + (-2 + (4 * random)), 85)
          .clamp(0, 100);
          
      sensorData['temperature'] = _ensureInt(30 + (10 * random), 32);
      sensorData['left_distance'] = _ensureInt(20 + (80 * random), 45);
      sensorData['right_distance'] = _ensureInt(20 + (80 * random), 38);
      sensorData['front_distance'] = _ensureInt(50 + (100 * random), 120);
      
      // Update power metrics too
      sensorData['solar_power'] = _ensureDouble(10 + (10 * random), 15.2);
      sensorData['current_draw'] = _ensureDouble(1.8 + (1 * random), 2.3);
      
      // Update uptime
      final parts = (sensorData['uptime'] as String).split(':');
      if (parts.length == 3) {
        int hours = int.parse(parts[0]);
        int minutes = int.parse(parts[1]);
        int seconds = int.parse(parts[2]);
        
        seconds += 2;  // Add 2 seconds (our update interval)
        if (seconds >= 60) {
          seconds = 0;
          minutes++;
        }
        if (minutes >= 60) {
          minutes = 0;
          hours++;
        }
        
        sensorData['uptime'] = '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      }
    });
  }
  
  // Helper methods to ensure proper types
  int _ensureInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        try {
          return double.parse(value).round();
        } catch (_) {
          return defaultValue;
        }
      }
    }
    return defaultValue;
  }
  
  double _ensureDouble(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (_) {
        return defaultValue;
      }
    }
    return defaultValue;
  }
}
