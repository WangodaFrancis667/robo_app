import 'package:flutter/material.dart';

class JoystickControlSection extends StatelessWidget {
  final int leftMotorSpeed;
  final int rightMotorSpeed;
  final Function(int, int) onMotorSpeedsChanged;
  final Function(String) onShowMessage;

  const JoystickControlSection({
    super.key,
    required this.leftMotorSpeed,
    required this.rightMotorSpeed,
    required this.onMotorSpeedsChanged,
    required this.onShowMessage,
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
                const Icon(Icons.control_camera, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Movement Control',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Motor Speed Indicators
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.blue.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.chevron_left, color: Colors.blue.shade700),
                        const SizedBox(height: 4),
                        Text(
                          'Left Motor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$leftMotorSpeed%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: leftMotorSpeed > 0
                                ? Colors.green.shade600
                                : leftMotorSpeed < 0
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade50, Colors.green.shade100],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.chevron_right, color: Colors.green.shade700),
                        const SizedBox(height: 4),
                        Text(
                          'Right Motor',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$rightMotorSpeed%',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: rightMotorSpeed > 0
                                ? Colors.green.shade600
                                : rightMotorSpeed < 0
                                ? Colors.red.shade600
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Directional Control Pad
            Center(
              child: Column(
                children: [
                  // Forward button
                  _buildDirectionalButton(
                    icon: Icons.keyboard_arrow_up,
                    onPressed: () => onMotorSpeedsChanged(60, 60),
                    onReleased: () => onMotorSpeedsChanged(0, 0),
                    color: Colors.green,
                    size: 60,
                  ),

                  const SizedBox(height: 8),

                  // Middle row with left, stop, right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDirectionalButton(
                        icon: Icons.keyboard_arrow_left,
                        onPressed: () => onMotorSpeedsChanged(-60, 60),
                        onReleased: () => onMotorSpeedsChanged(0, 0),
                        color: Colors.blue,
                        size: 60,
                      ),

                      const SizedBox(width: 16),

                      _buildDirectionalButton(
                        icon: Icons.stop,
                        onPressed: () => onMotorSpeedsChanged(0, 0),
                        onReleased: () {},
                        color: Colors.red,
                        size: 60,
                      ),

                      const SizedBox(width: 16),

                      _buildDirectionalButton(
                        icon: Icons.keyboard_arrow_right,
                        onPressed: () => onMotorSpeedsChanged(60, -60),
                        onReleased: () => onMotorSpeedsChanged(0, 0),
                        color: Colors.purple,
                        size: 60,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Backward button
                  _buildDirectionalButton(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: () => onMotorSpeedsChanged(-60, -60),
                    onReleased: () => onMotorSpeedsChanged(0, 0),
                    color: Colors.orange,
                    size: 60,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Speed Preset Buttons
            const Text(
              'Speed Presets',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSpeedPresetButton(
                    label: 'Slow',
                    speed: 30,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSpeedPresetButton(
                    label: 'Medium',
                    speed: 60,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSpeedPresetButton(
                    label: 'Fast',
                    speed: 90,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionalButton({
    required IconData icon,
    required VoidCallback onPressed,
    required VoidCallback onReleased,
    required Color color,
    required double size,
  }) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.4),
      ),
    );
  }

  Widget _buildSpeedPresetButton({
    required String label,
    required int speed,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: () {
        // This will be used for future directional movements with the selected speed
        onShowMessage('Speed preset set to $speed% - Use directional buttons');
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            '$speed%',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
