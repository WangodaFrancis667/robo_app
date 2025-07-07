import 'package:flutter/material.dart';
import 'robot_control_screen.dart';

class RobotControllerWrapper extends StatefulWidget {
  final Function(bool)? onConnectionStatusChanged;
  
  const RobotControllerWrapper({super.key, this.onConnectionStatusChanged});

  @override
  State<RobotControllerWrapper> createState() => _RobotControllerWrapperState();
}

class _RobotControllerWrapperState extends State<RobotControllerWrapper> {
  bool _isConnected = false;
  
  void _handleConnectionStatusChange(bool isConnected) {
    setState(() {
      _isConnected = isConnected;
    });
    
    if (widget.onConnectionStatusChanged != null) {
      widget.onConnectionStatusChanged!(isConnected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RobotControllerScreen(
          onConnectionStatusChanged: _handleConnectionStatusChange,
        ),
        // Show a floating back button when connected
        if (_isConnected)
          Positioned(
            top: 40,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  // Navigate back to main dashboard
                  Navigator.of(context).pushReplacementNamed('/');
                },
                tooltip: 'Exit Controls',
              ),
            ),
          ),
      ],
    );
  }
}
