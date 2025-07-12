import 'package:flutter/material.dart';
import '../services/video_service.dart';

class CameraDiscoveryDialog extends StatefulWidget {
  final VoidCallback onServerSelected;
  final Function(CameraServer) onServerConfigured;

  const CameraDiscoveryDialog({
    super.key,
    required this.onServerSelected,
    required this.onServerConfigured,
  });

  @override
  State<CameraDiscoveryDialog> createState() => _CameraDiscoveryDialogState();
}

class _CameraDiscoveryDialogState extends State<CameraDiscoveryDialog> {
  bool _isDiscovering = false;
  List<CameraServer> _discoveredServers = [];
  String _errorMessage = '';
  CameraServer? _selectedServer;

  @override
  void initState() {
    super.initState();
    _startDiscovery();
  }

  Future<void> _startDiscovery() async {
    setState(() {
      _isDiscovering = true;
      _errorMessage = '';
      _discoveredServers = [];
    });

    try {
      final videoService = VideoService();
      final discoveryResult = await videoService.performAutoDiscovery();

      setState(() {
        _isDiscovering = false;
        _discoveredServers = discoveryResult.cameraServers;
        _selectedServer = discoveryResult.bestServer;

        if (!discoveryResult.isSuccessful) {
          _errorMessage = discoveryResult.errorMessage ?? 'Discovery failed';
        }
      });
    } catch (e) {
      setState(() {
        _isDiscovering = false;
        _errorMessage = 'Discovery error: $e';
      });
    }
  }

  void _selectServer(CameraServer server) {
    setState(() {
      _selectedServer = server;
    });
  }

  void _useSelectedServer() {
    if (_selectedServer != null) {
      widget.onServerConfigured(_selectedServer!);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.search, color: Colors.blue),
          SizedBox(width: 8),
          Text('Camera Discovery'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isDiscovering)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Scanning network for camera servers...'),
                      SizedBox(height: 8),
                      Text(
                        'This may take a few moments',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (_errorMessage.isNotEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Discovery Failed',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _startDiscovery,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_discoveredServers.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Camera Servers Found',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Make sure your camera server is running and both devices are on the same network.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _startDiscovery,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${_discoveredServers.length} Camera Server(s)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a camera server to connect to:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _discoveredServers.length,
                        itemBuilder: (context, index) {
                          final server = _discoveredServers[index];
                          final isSelected = _selectedServer == server;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            color: isSelected ? Colors.blue.shade50 : null,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: server.isPiDevice
                                    ? Colors.green
                                    : Colors.orange,
                                child: Icon(
                                  server.isPiDevice
                                      ? Icons.device_hub
                                      : Icons.videocam,
                                  color: Colors.white,
                                ),
                              ),
                              title: Text(
                                '${server.ip}:${server.port}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Endpoint: ${server.endpoint}'),
                                  Text('Type: ${server.contentType}'),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.signal_cellular_alt,
                                        size: 16,
                                        color: _getConfidenceColor(
                                          server.confidence,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_getConfidenceText(server.confidence)} Confidence',
                                        style: TextStyle(
                                          color: _getConfidenceColor(
                                            server.confidence,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (server.isPiDevice) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.verified,
                                          size: 16,
                                          color: Colors.green,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'Raspberry Pi',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Radio<CameraServer>(
                                value: server,
                                groupValue: _selectedServer,
                                onChanged: (value) => _selectServer(value!),
                              ),
                              onTap: () => _selectServer(server),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Action buttons
            if (!_isDiscovering)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: _startDiscovery,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Scan Again'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _selectedServer != null
                          ? _useSelectedServer
                          : null,
                      child: const Text('Connect'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 10) return Colors.green;
    if (confidence >= 5) return Colors.orange;
    return Colors.red;
  }

  String _getConfidenceText(int confidence) {
    if (confidence >= 10) return 'High';
    if (confidence >= 5) return 'Medium';
    return 'Low';
  }
}
