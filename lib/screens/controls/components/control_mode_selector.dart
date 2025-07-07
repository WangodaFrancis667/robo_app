import 'package:flutter/material.dart';
import '../robot_control_screen.dart' show ControlMode;

class ControlModeSelectorSection extends StatelessWidget {
  final ControlMode currentControlMode;
  final Function(ControlMode) onControlModeChanged;

  const ControlModeSelectorSection({
    super.key,
    required this.currentControlMode,
    required this.onControlModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.blue.shade100],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onControlModeChanged(ControlMode.driving),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: currentControlMode == ControlMode.driving
                      ? LinearGradient(
                          colors: [Colors.blue.shade600, Colors.blue.shade500],
                        )
                      : null,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: currentControlMode == ControlMode.driving
                          ? Colors.white
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Driving',
                      style: TextStyle(
                        color: currentControlMode == ControlMode.driving
                            ? Colors.white
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onControlModeChanged(ControlMode.armControl),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  gradient: currentControlMode == ControlMode.armControl
                      ? LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade500,
                          ],
                        )
                      : null,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.precision_manufacturing,
                      color: currentControlMode == ControlMode.armControl
                          ? Colors.white
                          : Colors.blue.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Arm Control',
                      style: TextStyle(
                        color: currentControlMode == ControlMode.armControl
                            ? Colors.white
                            : Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
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
