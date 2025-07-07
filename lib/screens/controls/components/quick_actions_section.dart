import 'package:flutter/material.dart';

class QuickActionsSection extends StatelessWidget {
  final VoidCallback onHomeRobot;
  final VoidCallback onEmergencyStop;
  final VoidCallback onTestMotors;
  final VoidCallback onToggleDiagnostics;
  final bool motorDiagnostics;

  const QuickActionsSection({
    super.key,
    required this.onHomeRobot,
    required this.onEmergencyStop,
    required this.onTestMotors,
    required this.onToggleDiagnostics,
    required this.motorDiagnostics,
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
            const Text(
              '⚡ Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onHomeRobot,
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEmergencyStop,
                    icon: const Icon(Icons.emergency),
                    label: const Text('E-Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onTestMotors,
                    icon: const Icon(Icons.build),
                    label: const Text('Test Motors'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onToggleDiagnostics,
                    icon: Icon(
                      motorDiagnostics
                          ? Icons.bug_report
                          : Icons.bug_report_outlined,
                    ),
                    label: Text(motorDiagnostics ? 'Diag: ON' : 'Diag: OFF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: motorDiagnostics
                          ? Colors.green
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
