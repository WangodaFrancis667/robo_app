import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class VideoFeedSection extends StatelessWidget {
  final String streamUrl;
  final bool isLoadingStream;
  final String errorMessage;
  final bool isStreamActive;
  final Key mjpegKey;
  final VoidCallback onRefreshVideoStream;

  const VideoFeedSection({
    super.key,
    required this.streamUrl,
    required this.isLoadingStream,
    required this.errorMessage,
    required this.isStreamActive,
    required this.mjpegKey,
    required this.onRefreshVideoStream,
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
                const Icon(
                  Icons.videocam,
                  color: Colors.white,
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
                    color: isStreamActive ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isStreamActive ? 'LIVE' : 'OFFLINE',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Video content
          Expanded(child: _buildVideoWidget()),
        ],
      ),
    );
  }

  Widget _buildVideoWidget() {
    if (isLoadingStream) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white54),
            SizedBox(height: 16),
            Icon(Icons.videocam, size: 48, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Connecting to Camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            const Text(
              'Camera Offline',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefreshVideoStream,
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
    }

    if (isStreamActive) {
      return Mjpeg(
        key: mjpegKey,
        isLive: true,
        stream: streamUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
        loading: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
        error: (context, error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(
                'Stream Error: $error',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 48, color: Colors.white54),
          SizedBox(height: 16),
          Text(
            'No Video Feed',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
