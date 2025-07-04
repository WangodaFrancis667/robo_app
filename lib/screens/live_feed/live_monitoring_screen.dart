import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

/// The screen responsible for displaying live camera stream and robot controls.
class LiveMonitoringScreen extends StatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  // Replace with your Raspberry Pi's IP address
  final String _raspberryPiIP = '192.168.1.8'; // Change this to your Pi's IP

  // Robot control URL (if your robot control is also on the Pi)
  String get controlUrl => 'http://$_raspberryPiIP:5000/control';

  // Camera stream URL - this matches the Python server endpoint
  String get streamUrl => 'http://$_raspberryPiIP:8080/my_mac_camera';

  // State variables for robot status and controls
  bool isEmergencyStop = false;
  String robotStatus = 'Active';
  String currentTask = 'Scanning for weeds';

  // State variables for UI feedback
  bool _isLoadingStream = false;
  String _errorMessage = '';
  bool _isStreamActive = false;

  // Key for rebuilding the MJPEG widget
  Key _mjpegKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // Test connectivity and start streaming
    _testAndStartStreaming();
  }

  @override
  void dispose() {
    // No manual cleanup needed for flutter_mjpeg
    super.dispose();
  }

  /// Refresh the MJPEG stream
  void _refreshStream() {
    setState(() {
      _mjpegKey = UniqueKey(); // This will force rebuild of the Mjpeg widget
      _errorMessage = '';
    });
  }

  /// Test connectivity and start streaming
  Future<void> _testAndStartStreaming() async {
    setState(() {
      _isLoadingStream = true;
      _errorMessage = '';
    });

    debugPrint('🚀 Testing connectivity to camera server...');

    // Test if the camera server is running
    bool serverRunning = await _testConnectivity(streamUrl);

    if (!serverRunning) {
      debugPrint(
        'Primary connectivity test failed, trying alternative method...',
      );
      serverRunning = await _testConnectivityAlternative(
        'http://$_raspberryPiIP:8080',
      );
    }

    if (serverRunning) {
      debugPrint('✅ Server is reachable, stream ready');
      setState(() {
        _isLoadingStream = false;
        _isStreamActive = true;
        _errorMessage = '';
      });
    } else {
      debugPrint(
        '❌ Server not reachable, attempting to start remote camera...',
      );
      // Try to start the camera on the server
      await _startRemoteCamera();

      // Wait a bit for the camera to start
      await Future.delayed(const Duration(seconds: 3));

      // Try again
      bool retryResult = await _testConnectivity(streamUrl);
      if (retryResult) {
        debugPrint('✅ Camera started successfully');
        setState(() {
          _isLoadingStream = false;
          _isStreamActive = true;
          _errorMessage = '';
        });
      } else {
        debugPrint('❌ Unable to establish connection after retry');
        setState(() {
          _isLoadingStream = false;
          _isStreamActive = false;
          _errorMessage =
              'Unable to connect to camera server.\n'
              'Please verify:\n'
              '• Camera server is running on Raspberry Pi\n'
              '• IP address $_raspberryPiIP is correct\n'
              '• Port 8080 is accessible\n'
              '• Both devices are on same network';
        });
      }
    }
  }

  /// Test basic connectivity to the server
  Future<bool> _testConnectivity(String url) async {
    try {
      debugPrint('Testing basic connectivity to: $url');

      final client = http.Client();
      try {
        final response = await client
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));

        debugPrint('Test response status: ${response.statusCode}');

        if (response.statusCode == 200) {
          debugPrint('✅ Successfully connected to camera server');
          return true;
        } else {
          debugPrint('❌ Server responded with status: ${response.statusCode}');
          return false;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('❌ Connectivity test failed: $e');
      return false;
    }
  }

  /// Alternative connectivity test using different endpoints
  Future<bool> _testConnectivityAlternative(String baseUrl) async {
    try {
      debugPrint('Testing alternative connectivity to base URL: $baseUrl');

      final endpoints = [
        '$baseUrl/',
        '$baseUrl/my_mac_camera', // Test the actual stream endpoint
        '$baseUrl/health',
        '$baseUrl/camera/status',
      ];

      for (String endpoint in endpoints) {
        try {
          debugPrint('Trying endpoint: $endpoint');
          final client = http.Client();

          try {
            final response = await client
                .get(Uri.parse(endpoint))
                .timeout(const Duration(seconds: 8));

            debugPrint('Response status for $endpoint: ${response.statusCode}');
            debugPrint('Content-Type: ${response.headers['content-type']}');

            if (response.statusCode == 200) {
              debugPrint('✅ Successfully connected to: $endpoint');

              // If this is the camera endpoint, check if it's actually streaming
              if (endpoint.contains('/my_mac_camera')) {
                final contentType = response.headers['content-type'];
                if (contentType != null &&
                    contentType.contains('multipart/x-mixed-replace')) {
                  debugPrint('✅ MJPEG stream endpoint confirmed working');
                  return true;
                } else {
                  debugPrint(
                    '⚠️ Endpoint exists but may not be streaming MJPEG',
                  );
                }
              }
              return true;
            }
          } finally {
            client.close();
          }
        } catch (e) {
          debugPrint('Failed to connect to $endpoint: $e');
          continue;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Alternative connectivity test failed: $e');
      return false;
    }
  }

  /// Start the camera remotely
  Future<void> _startRemoteCamera() async {
    try {
      final response = await http
          .post(
            Uri.parse('http://$_raspberryPiIP:8080/camera/start'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('Camera started remotely');
      } else {
        debugPrint('Failed to start remote camera: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error starting remote camera: $e');
    }
  }

  /// Get camera status
  Future<Map<String, dynamic>?> getCameraStatus() async {
    try {
      final response = await http
          .get(Uri.parse('http://$_raspberryPiIP:8080/camera/status'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error getting camera status: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Robot Monitoring'),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
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
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: _buildVideoWidget(),
                ),
              ),
            ),
          ),

          // Status Cards
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Current Task Card
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.task_alt, color: Colors.blue),
                      title: const Text('Current Task'),
                      subtitle: Text(currentTask),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: _refreshStream,
                        tooltip: 'Refresh Camera Stream',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emergency Controls
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _toggleEmergencyStop(),
                          icon: Icon(
                            isEmergencyStop ? Icons.play_arrow : Icons.stop,
                          ),
                          label: Text(
                            isEmergencyStop ? 'Resume' : 'Emergency Stop',
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEmergencyStop
                                ? Colors.green
                                : Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _returnToBase(),
                          icon: const Icon(Icons.home),
                          label: const Text(
                            'Return to Base',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 5,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshStream,
        tooltip: 'Refresh Stream',
        backgroundColor: Colors.green,
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildVideoWidget() {
    if (_isLoadingStream) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.white54),
          const SizedBox(height: 16),
          const Icon(Icons.videocam, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'Connecting to Live Camera Feed...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          Text(
            streamUrl,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off, size: 64, color: Colors.white54),
          const SizedBox(height: 16),
          const Text(
            'Camera Connection Failed',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _testAndStartStreaming,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    if (_isStreamActive) {
      debugPrint('🎥 Attempting to display MJPEG stream: $streamUrl');
      return Mjpeg(
        key: _mjpegKey,
        isLive: true,
        stream: streamUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        loading: (context) => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white54),
              SizedBox(height: 10),
              Text(
                'Loading video stream...',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ],
          ),
        ),
        error: (context, error, stack) {
          debugPrint('🚨 MJPEG Stream Error: $error');
          debugPrint('Stack trace: $stack');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, color: Colors.red, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Stream Error',
                  style: TextStyle(color: Colors.red, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Error: $error',
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'URL: $streamUrl',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _refreshStream,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
        timeout: const Duration(seconds: 15), // Increased timeout
      );
    }

    // Default state
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        const Text(
          'Live Camera Feed',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        Text(
          streamUrl,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _testAndStartStreaming,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Stream'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _toggleEmergencyStop() async {
    setState(() {
      isEmergencyStop = !isEmergencyStop;
      robotStatus = isEmergencyStop ? 'Stopped' : 'Active';
      currentTask = isEmergencyStop ? 'None' : 'Scanning for weeds';
    });

    // Send control command to robot
    try {
      final response = await http.post(
        Uri.parse(controlUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': isEmergencyStop ? 'stop' : 'resume'}),
      );
      if (response.statusCode == 200) {
        debugPrint('Control command sent successfully: ${response.body}');
      } else {
        debugPrint(
          'Failed to send control command: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      debugPrint('Error sending control command: $e');
    }
  }

  void _returnToBase() async {
    setState(() {
      currentTask = 'Returning to base station';
      robotStatus = 'Returning';
    });

    try {
      final response = await http.post(
        Uri.parse(controlUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'action': 'return_home'}),
      );
      if (response.statusCode == 200) {
        debugPrint('Return home command sent successfully: ${response.body}');
      } else {
        debugPrint(
          'Failed to send return home command: ${response.statusCode} ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      debugPrint('Error sending return home command: $e');
    }
  }
}
