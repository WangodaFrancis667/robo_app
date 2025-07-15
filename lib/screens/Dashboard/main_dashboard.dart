import 'package:flutter/material.dart';
import 'package:robo_app/screens/controls/robot_control_screen.dart';
import 'package:robo_app/screens/live_feed/live_monitoring_screen.dart';
import 'package:robo_app/screens/sensors/sensor_dashboard_screen.dart';
import 'package:robo_app/screens/logs/weeding_logs_screen.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  MainDashboardState createState() => MainDashboardState();
}

class MainDashboardState extends State<MainDashboard> {
  int _currentIndex = 0;
  bool _hideBottomBar = false;
  bool _isRobotConnected = false;

  final String baseUrl = 'http://192.168.1.100:5000';

  void _onRobotConnectionChanged(bool isConnected) {
    setState(() {
      _isRobotConnected = isConnected;
      // Hide bottom bar when robot is connected in controls tab
      _hideBottomBar = (_currentIndex == 1 && isConnected);
    });
  }

  List<Widget> get _screens => [
    LiveMonitoringScreen(),
    RobotControllerApp(onConnectionStatusChanged: _onRobotConnectionChanged),
    // Pass standalone mode as true for the sensor dashboard tab
    const RobotSensorDashboard(standaloneMode: true),
    WeedingLogsScreen(),
  ];

  void _onTabChanged(int index) {
    setState(() {
      _currentIndex = index;
      // Hide bottom bar when on controls tab (index 1) and robot is connected
      _hideBottomBar = (index == 1 && _isRobotConnected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: _hideBottomBar
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: _onTabChanged,
              selectedItemColor: Colors.green,
              unselectedItemColor: Colors.grey,
              backgroundColor: Colors.white,
              elevation: 8,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.videocam),
                  label: 'Live Feed',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.control_camera),
                  label: 'Controls',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.sensors),
                  label: 'Sensors',
                ),
                // BottomNavigationBarItem(
                //   icon: Icon(Icons.history),
                //   label: 'Logs',
                // ),
              ],
            ),
      // Show a floating action button to go back when bottom bar is hidden
      floatingActionButton: _hideBottomBar
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _currentIndex = 0; // Go back to Live Feed
                  _hideBottomBar = false;
                });
              },
              backgroundColor: Colors.green,
              tooltip: 'Back to Dashboard',
              child: const Icon(Icons.home, color: Colors.white),
            )
          : null,
    );
  }
}
