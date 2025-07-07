import 'package:flutter/material.dart';

class DiscoveryStatusWidget extends StatelessWidget {
  final bool isDiscovering;
  final String statusMessage;
  final VoidCallback? onRetry;

  const DiscoveryStatusWidget({
    super.key,
    required this.isDiscovering,
    required this.statusMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          if (isDiscovering)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.search,
              color: Colors.blue.shade600,
              size: 20,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusMessage,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (!isDiscovering && onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              iconSize: 20,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}
