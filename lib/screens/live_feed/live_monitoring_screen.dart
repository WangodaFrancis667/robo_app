import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Main entry point for the Flutter application.
void main() {
  runApp(const CameraStreamApp());
}

/// The root widget for the camera stream application.
class CameraStreamApp extends StatelessWidget {
  const CameraStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Live Robot Monitoring',
      theme: ThemeData(
        primarySwatch:
            Colors.green, // Changed primary color to green for robot theme
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter', // Using Inter font for a modern look.
      ),
      home:
          const LiveMonitoringScreen(), // Changed home to LiveMonitoringScreen
    );
  }
}

/// The screen responsible for displaying live camera stream and robot controls.
class LiveMonitoringScreen extends StatefulWidget {
  const LiveMonitoringScreen({super.key});

  @override
  State<LiveMonitoringScreen> createState() => _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends State<LiveMonitoringScreen> {
  // Robot control URL (replace with your actual robot control server IP and port)
  final String controlUrl = 'http://192.168.1.6:5000/control';
  // MJPEG camera stream URL (replace with your Mac's actual IP and port)
  final String streamUrl =
      'http://192.168.1.6:8080/my_mac_camera'; // Using user's provided stream URL

  // State variables for robot status and controls
  bool isEmergencyStop = false;
  String robotStatus = 'Active';
  String currentTask = 'Scanning for weeds';

  // StreamController to push decoded image bytes to the UI.
  StreamController<Uint8List>? _imageStreamController;
  // HTTP client for making requests to the camera stream.
  http.Client? _streamClient; // Renamed to avoid conflict with control client
  // HTTP request object for the stream.
  http.Request? _streamRequest;
  // Subscription to the HTTP response stream.
  StreamSubscription<List<int>>? _responseSubscription;

  // State variables for UI feedback.
  bool _isLoadingStream = false; // Renamed to be specific to stream loading
  String _errorMessage = '';
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // Automatically start streaming when the screen initializes.
    _startStreaming(streamUrl);
  }

  /// Initiates the streaming process from the provided URL.
  Future<void> _startStreaming(String url) async {
    // Reset state and prepare for new stream.
    setState(() {
      _isLoadingStream = true;
      _errorMessage = '';
      _retryCount = 0; // Reset retry count
      _imageStreamController?.close(); // Close any previous stream.
      _imageStreamController = StreamController<Uint8List>();
      _streamClient?.close(); // Close any previous HTTP client.
      _streamClient = http.Client();
    });

    try {
      // Create an HTTP GET request to the specified URL.
      _streamRequest = http.Request('GET', Uri.parse(url));
      final http.StreamedResponse response = await _streamClient!.send(
        _streamRequest!,
      );

      // Check if the connection was successful (HTTP 200 OK).
      if (response.statusCode == 200) {
        // Extract the MJPEG boundary from the Content-Type header.
        final contentType = response.headers['content-type'];
        String boundary = 'frame'; // Default boundary if not specified.
        if (contentType != null && contentType.contains('boundary=')) {
          boundary = contentType.split('boundary=')[1].trim();
        }

        // Encode the boundary strings for byte-level comparison.
        final boundaryBytes = utf8.encode('\r\n--$boundary');
        final startBoundaryBytes = utf8.encode('--$boundary');
        final doubleNewlineBytes = utf8.encode(
          '\r\n\r\n',
        ); // Separates headers from image data.

        List<int> buffer = []; // Buffer to accumulate incoming bytes.

        // Listen to the incoming byte stream from the HTTP response.
        _responseSubscription = response.stream.listen(
          (List<int> chunk) {
            buffer.addAll(chunk); // Add new chunk to the buffer.

            // Continuously process the buffer to extract full JPEG frames.
            while (true) {
              int currentBoundaryIndex = -1;

              // Try to find the initial boundary or subsequent boundaries.
              if (buffer.length >= startBoundaryBytes.length &&
                  _indexOfBytes(
                        buffer.sublist(0, startBoundaryBytes.length),
                        startBoundaryBytes,
                      ) !=
                      -1) {
                currentBoundaryIndex = _indexOfBytes(
                  buffer,
                  startBoundaryBytes,
                );
              } else {
                currentBoundaryIndex = _indexOfBytes(buffer, boundaryBytes);
              }

              if (currentBoundaryIndex == -1) {
                // No full boundary found yet, wait for more data.
                break;
              }

              // Calculate the start of the headers after the current boundary.
              int headersStartIndex =
                  currentBoundaryIndex +
                  (currentBoundaryIndex ==
                          _indexOfBytes(buffer, startBoundaryBytes)
                      ? startBoundaryBytes.length
                      : boundaryBytes.length);

              // Find the `\r\n\r\n` sequence that marks the end of headers and start of image data.
              int headerEndIndex = _indexOfBytes(
                buffer.sublist(headersStartIndex),
                doubleNewlineBytes,
              );

              if (headerEndIndex == -1) {
                // Headers not fully received yet, wait for more data.
                break;
              }

              // Calculate the actual start of the JPEG image data.
              int imageStartIndex =
                  headersStartIndex +
                  headerEndIndex +
                  doubleNewlineBytes.length;

              // Look for the NEXT boundary to determine where the current JPEG image ends.
              int nextBoundaryIndex = _indexOfBytes(
                buffer.sublist(imageStartIndex),
                boundaryBytes,
              );

              if (nextBoundaryIndex == -1) {
                // The next boundary is not yet in the buffer, meaning the current image
                // might not be fully received. Wait for more data.
                break;
              }

              // Extract the JPEG bytes for the current frame.
              Uint8List jpegBytes = Uint8List.fromList(
                buffer.sublist(
                  imageStartIndex,
                  imageStartIndex + nextBoundaryIndex,
                ),
              );

              // Add the decoded JPEG image to the stream controller for UI update.
              _imageStreamController?.add(jpegBytes);

              // Remove the processed frame (including its boundary and headers) from the buffer.
              buffer = buffer.sublist(imageStartIndex + nextBoundaryIndex);
            }
          },
          // Error handling for the stream.
          onError: (error) {
            debugPrint('Stream error: $error');
            if (mounted) {
              setState(() {
                _errorMessage = 'Stream error: $error';
                _isLoadingStream = false;
              });
            }
            _imageStreamController?.close();
          },
          // Called when the stream finishes (e.g., server closes connection).
          onDone: () {
            debugPrint('Stream finished.');
            if (mounted) {
              setState(() {
                _isLoadingStream = false;
              });
            }
            _imageStreamController?.close();
          },
        );
      } else {
        // Handle non-200 HTTP status codes.
        if (mounted) {
          setState(() {
            _errorMessage =
                'Failed to connect: ${response.statusCode} ${response.reasonPhrase}';
            _isLoadingStream = false;
          });
        }
        _imageStreamController?.close();
      }
    } catch (e) {
      // Catch any network or parsing errors.
      debugPrint('Error sending request: $e');

      // Implement retry logic for connection failures
      if (_retryCount < _maxRetries) {
        _retryCount++;
        debugPrint('Retrying connection... Attempt $_retryCount/$_maxRetries');
        debugPrint('Error details: $e');
        await Future.delayed(
          Duration(seconds: _retryCount * 2),
        ); // Exponential backoff
        if (mounted) {
          _startStreaming(url); // Retry
        }
        return;
      }

      if (mounted) {
        setState(() {
          _errorMessage =
              'Error connecting: $e${_retryCount >= _maxRetries ? ' (Max retries reached)' : ''}';
          _isLoadingStream = false;
        });
      }
      _imageStreamController?.close();
    }
  }

  /// Helper function to find a sequence of bytes within another list of bytes.
  /// Used for finding MJPEG boundaries and header delimiters.
  int _indexOfBytes(List<int> source, List<int> target) {
    if (target.isEmpty) return 0;
    if (source.isEmpty || target.length > source.length) return -1;

    for (int i = 0; i <= source.length - target.length; i++) {
      bool found = true;
      for (int j = 0; j < target.length; j++) {
        if (source[i + j] != target[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }

  /// Stops the active camera stream and cleans up resources.
  void _stopStreaming() {
    _responseSubscription?.cancel(); // Cancel the stream subscription.
    _imageStreamController?.close(); // Close the image stream controller.
    _streamClient?.close(); // Close the HTTP client.
    if (mounted) {
      setState(() {
        _isLoadingStream = false;
        _imageStreamController = null;
        _streamClient = null;
        _errorMessage = '';
        _retryCount = 0;
      });
    }
  }

  @override
  void dispose() {
    _stopStreaming(); // Ensure resources are cleaned up when the widget is disposed.
    super.dispose();
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
                  alignment: Alignment.center, // Center the content
                  child: _imageStreamController == null || _isLoadingStream
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLoadingStream)
                              const CircularProgressIndicator(
                                color: Colors.white54,
                              ),
                            if (_isLoadingStream) const SizedBox(height: 16),
                            Icon(
                              Icons.videocam,
                              size: 64,
                              color: Colors.white54,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isLoadingStream
                                  ? 'Connecting to Live Camera Feed...'
                                  : 'Live Camera Feed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              streamUrl,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (_errorMessage.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: Column(
                                  children: [
                                    Text(
                                      _errorMessage,
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          _startStreaming(streamUrl),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry Connection'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        )
                      : StreamBuilder<Uint8List>(
                          stream: _imageStreamController!.stream,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              // Display the image from the received bytes.
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit
                                    .contain, // Adjusts image to fit within bounds.
                                gaplessPlayback:
                                    true, // Prevents flickering between frames.
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.broken_image,
                                    color: Colors.red,
                                    size: 80,
                                  );
                                },
                              );
                            } else if (snapshot.hasError) {
                              // Display error if stream encounters one.
                              return Text(
                                'Error receiving image: ${snapshot.error}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              );
                            } else {
                              // Placeholder while waiting for the first frame.
                              return const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white54,
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Waiting for stream data...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
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
                      trailing: const Icon(
                        Icons.refresh,
                      ), // Placeholder for refresh, could trigger a status update
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
                          ), // Change icon based on state
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
    );
  }

  void _toggleEmergencyStop() async {
    setState(() {
      isEmergencyStop = !isEmergencyStop;
      robotStatus = isEmergencyStop ? 'Stopped' : 'Active';
      currentTask = isEmergencyStop
          ? 'None'
          : 'Scanning for weeds'; // Reset task if resumed
    });

    // Send control command to robot
    try {
      final response = await http.post(
        Uri.parse(controlUrl), // Use the defined controlUrl
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
      robotStatus = 'Returning'; // Update status when returning to base
    });

    try {
      final response = await http.post(
        Uri.parse(controlUrl), // Use the defined controlUrl
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

  /// Test basic connectivity to the server
  Future<bool> _testConnectivity(String url) async {
    try {
      debugPrint('Testing basic connectivity to: $url');
      final response = await http
          .get(Uri.parse(url))
          .timeout(Duration(seconds: 5));
      debugPrint('Test response status: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Connectivity test failed: $e');
      return false;
    }
  }
}
