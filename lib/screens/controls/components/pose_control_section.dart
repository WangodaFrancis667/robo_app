import 'package:flutter/material.dart';
import 'package:robo_app/utils/colors.dart';

class PoseControlSection extends StatelessWidget {
  final List<String> poses;
  final Function(String) onSetPose;

  const PoseControlSection({
    super.key,
    required this.poses,
    required this.onSetPose,
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
                const Icon(Icons.accessibility_new, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Predefined Poses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: poses.map((pose) {
                IconData icon;
                Color color;
                switch (pose) {
                  case 'Home':
                    icon = Icons.home;
                    color = Colors.red;
                    break;
                  case 'Pick':
                    icon = Icons.pan_tool;
                    color = Colors.green;
                    break;
                  case 'Place':
                    icon = Icons.place;
                    color = Colors.orange;
                    break;
                  case 'Rest':
                    icon = Icons.hotel;
                    color = Colors.purple;
                    break;
                  default:
                    icon = Icons.settings;
                    color = Colors.black;
                }

                return ElevatedButton.icon(
                  onPressed: () => onSetPose(pose),
                  icon: Icon(icon),
                  label: Text(pose),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,//.withValues(alpha: 0.1),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
