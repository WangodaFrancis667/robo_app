import 'package:flutter/material.dart';
import 'package:robo_app/screens/live_feed/live_monitoring_screen.dart';
import 'package:robo_app/screens/controls/robot_control_screen.dart';
import 'package:robo_app/screens/sensors/sensor_dashboard_screen.dart';
import 'package:robo_app/screens/logs/weeding_logs_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  MainDashboardState createState() => MainDashboardState();
}

class MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;

  final String baseUrl = 'http://192.168.1.100:5000';

  final List<Widget> _screens = [
    LiveMonitoringScreen(),
    RobotControlScreen(),
    SensorDashboardScreen(),
    WeedingLogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: 'Live Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.control_camera),
            label: 'Controls',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.sensors), label: 'Sensors'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Logs'),
        ],
      ),
    );
  }
}
