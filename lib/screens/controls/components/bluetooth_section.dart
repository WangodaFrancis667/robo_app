// components/bluetooth_section.dart
import 'package:flutter/material.dart';
import '../services/bluetoth_service.dart';
import '../services/video_service.dart';

class BluetoothConnectionSection extends StatefulWidget {
  final List<BluetoothDevice> bondedDevices;
  final bool isConnecting;
  final BluetoothDevice? selectedDevice;
  final VoidCallback onRefreshDevices;
  final VoidCallback onShowConnectionTips;
  final Function(BluetoothDevice) onConnectToDevice;
  final Function(CameraServer)? onCameraServerDiscovered;

  const BluetoothConnectionSection({
    super.key,
    required this.bondedDevices,
    required this.isConnecting,
    this.selectedDevice,
    required this.onRefreshDevices,
    required this.onShowConnectionTips,
    required this.onConnectToDevice,
    this.onCameraServerDiscovered,
  });

  @override
  State<BluetoothConnectionSection> createState() =>
      _BluetoothConnectionSectionState();
}

class _BluetoothConnectionSectionState
    extends State<BluetoothConnectionSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.bluetooth,
                size: 32,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connect to Robot',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Select your Arduino/ESP32 device',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onShowConnectionTips,
                icon: const Icon(Icons.help_outline),
                tooltip: 'Connection Tips',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Connection status
          if (widget.isConnecting) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Connecting...',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Connecting to ${widget.selectedDevice?.name ?? "device"}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Device list header
          Row(
            children: [
              const Text(
                'Available Devices',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.isConnecting ? null : widget.onRefreshDevices,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Device list
          Expanded(
            child: widget.bondedDevices.isEmpty
                ? _buildEmptyState()
                : _buildDeviceList(),
          ),

          // Footer information
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Connection Process',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  '1. Robot connects via Bluetooth first\n'
                  '2. Camera initializes after robot connection\n'
                  '3. Both can work independently',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Bluetooth Devices Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Make sure your robot is:\n'
            '• Powered on and running\n'
            '• HC module LED is blinking\n'
            '• Paired in Android Bluetooth settings first\n'
            '• Not connected to another device',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: widget.onRefreshDevices,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan Again'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: widget.onShowConnectionTips,
            child: const Text('View Connection Tips'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      itemCount: widget.bondedDevices.length,
      itemBuilder: (context, index) {
        final device = widget.bondedDevices[index];
        final isSelected = widget.selectedDevice == device;
        final isConnecting = widget.isConnecting && isSelected;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Card(
            elevation: isSelected ? 4 : 1,
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getDeviceIconColor(device).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getDeviceIcon(device),
                  color: _getDeviceIconColor(device),
                ),
              ),
              title: Text(
                device.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.address,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (isConnecting) ...[
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Connecting...',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ElevatedButton(
                      onPressed: () => widget.onConnectToDevice(device),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getDeviceIconColor(device),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Connect'),
                    ),
              onTap: isConnecting
                  ? null
                  : () => widget.onConnectToDevice(device),
            ),
          ),
        );
      },
    );
  }

  IconData _getDeviceIcon(BluetoothDevice device) {
    final name = device.name.toLowerCase();

    if (name.contains('esp32') || name.contains('arduino')) {
      return Icons.memory;
    } else if (name.contains('robot') || name.contains('bot')) {
      return Icons.smart_toy;
    } else if (name.contains('mega') || name.contains('uno')) {
      return Icons.developer_board;
    } else {
      return Icons.bluetooth;
    }
  }

  Color _getDeviceIconColor(BluetoothDevice device) {
    final name = device.name.toLowerCase();

    if (name.contains('esp32')) {
      return Colors.blue;
    } else if (name.contains('arduino')) {
      return Colors.teal;
    } else if (name.contains('robot') || name.contains('bot')) {
      return Colors.purple;
    } else {
      return Colors.grey;
    }
  }
}

// components/video_feed_section.dart (simplified)
class VideoFeedSection extends StatelessWidget {
  final String streamUrl;
  final bool isLoadingStream;
  final String errorMessage;
  final bool isStreamActive;
  final Key mjpegKey;
  final VoidCallback onRefreshVideoStream;
  final Function(CameraServer)? onCameraServerDiscovered;

  const VideoFeedSection({
    super.key,
    required this.streamUrl,
    required this.isLoadingStream,
    required this.errorMessage,
    required this.isStreamActive,
    required this.mjpegKey,
    required this.onRefreshVideoStream,
    this.onCameraServerDiscovered,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // Video header
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey.shade900,
            child: Row(
              children: [
                Icon(
                  isStreamActive ? Icons.videocam : Icons.videocam_off,
                  color: isStreamActive ? Colors.green : Colors.white54,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Live Camera Feed',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isStreamActive
                        ? Colors.green
                        : isLoadingStream
                        ? Colors.orange
                        : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isStreamActive
                        ? 'LIVE'
                        : isLoadingStream
                        ? 'LOADING'
                        : 'OFFLINE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onRefreshVideoStream,
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Refresh Video',
                ),
              ],
            ),
          ),

          // Video content
          Expanded(
            child: isLoadingStream
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Initializing Camera...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  )
                : isStreamActive
                ? Image.network(
                    streamUrl,
                    key: mjpegKey,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Camera Error',
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              error.toString(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            size: 48,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Camera Not Available',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage.isEmpty
                                ? 'Camera will connect after robot is ready'
                                : errorMessage,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: onRefreshVideoStream,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry Camera'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
