import 'package:flutter/material.dart';

class SpeedControlSection extends StatelessWidget {
  final int globalSpeedMultiplier;
  final Function(int) onSpeedChanged;

  const SpeedControlSection({
    super.key,
    required this.globalSpeedMultiplier,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.speed, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Global Speed Control',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.remove, color: Colors.grey),
                Expanded(
                  child: Slider(
                    value: globalSpeedMultiplier.toDouble(),
                    min: 20,
                    max: 100,
                    divisions: 16,
                    label: '$globalSpeedMultiplier%',
                    onChanged: (value) => onSpeedChanged(value.round()),
                  ),
                ),
                const Icon(Icons.add, color: Colors.grey),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '20%\nSlow',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$globalSpeedMultiplier%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                Text(
                  '100%\nFast',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
