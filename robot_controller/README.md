# 4WD Robot with 6-Servo Arm - Bluetooth Control System

A modular Arduino Mega 2560 control system for a 4-wheel drive robot with a 6-servo robotic arm, controlled via Bluetooth.

## 📁 Project Structure

```
robot_controller/
├── main.ino                 # Main entry point
├── config.h                 # Configuration and pin definitions
├── bluetooth_handler.h      # Bluetooth communication
├── motor_controller.h       # 4-wheel motor control
├── servo_arm.h             # 6-servo arm control
├── command_processor.h      # Command parsing and execution
├── system_status.h         # System monitoring and safety
└── README.md               # This file
```

## 🔧 Hardware Requirements

### Arduino Mega 2560
- Main microcontroller board

### Motor Control
- 2x Motor driver boards (L298N or similar)
- 4x DC motors for wheels
- Motor power supply (7-12V recommended)

### Servo Arm
- 6x Servo motors (SG90 or similar)
- Servo power supply (5V, adequate current rating)

### Bluetooth Communication
- HC-05 or HC-06 Bluetooth module

### Optional
- Emergency stop button
- Status LED (built-in LED pin 13 used by default)

## 🔌 Pin Connections

### Motor Drivers
```
Driver 1 (Left Motors):
- D0 (Pin 22) → Front Left Motor Control 1
- D1 (Pin 23) → Front Left Motor Control 2
- D2 (Pin 24) → Rear Left Motor Control 1
- D3 (Pin 25) → Rear Left Motor Control 2
- EN1 (Pin 2) → Front Left Motor PWM
- EN2 (Pin 3) → Rear Left Motor PWM

Driver 2 (Right Motors):
- D0 (Pin 26) → Front Right Motor Control 1
- D1 (Pin 27) → Front Right Motor Control 2
- D2 (Pin 28) → Rear Right Motor Control 1
- D3 (Pin 29) → Rear Right Motor Control 2
- EN1 (Pin 4) → Front Right Motor PWM
- EN2 (Pin 5) → Rear Right Motor PWM
```

### Servo Arm
```
- Pin 6  → Base Rotation Servo
- Pin 7  → Shoulder Servo
- Pin 8  → Elbow Servo
- Pin 9  → Wrist Rotation Servo
- Pin 10 → Wrist Tilt Servo
- Pin 11 → Gripper Servo
```

### Bluetooth Module
```
- Pin 18 (TX1) → HC-05 RX
- Pin 19 (RX1) → HC-05 TX
- 5V → HC-05 VCC
- GND → HC-05 GND
```

### Optional Components
```
- Pin 12 → Emergency Stop Button (optional)
- Pin 13 → Status LED (built-in)
```

## 📦 Installation

1. **Download the code** to your Arduino IDE
2. **Install required libraries**:
   - Servo library (usually included with Arduino IDE)
3. **Configure pins** in `config.h` if needed
4. **Upload** `main.ino` to your Arduino Mega 2560

## ⚙ Configuration

Edit `config.h` to customize:

### Debug Settings
```cpp
#define DEBUG_ENABLED true      // Enable/disable debug output
#define DEBUG_MOTOR true        // Motor debug messages
#define DEBUG_SERVO true        // Servo debug messages
#define DEBUG_BLUETOOTH true    // Bluetooth debug messages
```

### Safety Settings
```cpp
#define COMMAND_TIMEOUT 2000    // Command timeout in ms
#define MIN_SPEED_THRESHOLD 20  // Minimum motor speed
#define MAX_SPEED_LIMIT 100     // Maximum motor speed
```

### Motor Direction Correction
If any motor runs backwards, change these values to -1:
```cpp
#define FRONT_LEFT_DIR 1        // Set to -1 if reversed
#define REAR_LEFT_DIR 1         // Set to -1 if reversed
#define FRONT_RIGHT_DIR -1      // Set to -1 if reversed
#define REAR_RIGHT_DIR -1       // Set to -1 if reversed
```

## 📱 Bluetooth Commands

### Motor Control Commands
```
FORWARD:speed     # Move forward (speed: 0-100)
BACKWARD:speed    # Move backward (speed: 0-100)
LEFT:speed        # Turn left (speed: 0-100)
RIGHT:speed       # Turn right (speed: 0-100)
TANK:left,right   # Tank drive (speeds: -100 to 100)
STOP              # Stop all motors
```

### Servo Arm Commands
```
ARM_HOME          # Move arm to home position
ARM_PRESET:1-5    # Move to preset position (1-5)
SERVO1:angle      # Control base servo (0-180°)
SERVO2:angle      # Control shoulder servo (0-180°)
SERVO3:angle      # Control elbow servo (0-180°)
SERVO4:angle      # Control wrist rotation (0-180°)
SERVO5:angle      # Control wrist tilt (0-180°)
SERVO6:angle      # Control gripper (0-180°)
GRIPPER_OPEN      # Open gripper fully
GRIPPER_CLOSE     # Close gripper fully
```

### System Commands
```
STATUS            # Get system status
SPEED:value       # Set global motor speed (20-100)
SERVO_SPEED:val   # Set servo movement speed (1-5)
DEBUG:0/1         # Toggle debug mode
EMERGENCY         # Emergency stop all movement
TEST_MOTORS       # Test all motors
TEST_SERVOS       # Test all servos
CALIBRATE         # Calibrate servos to 90°
PING              # Connection test (responds with PONG)
HELP              # Show command help
```

## 🏠 Servo Arm Presets

1. **Preset 1**: Pickup position - optimized for picking up objects
2. **Preset 2**: Place position - optimized for placing objects
3. **Preset 3**: Rest position - compact storage position
4. **Preset 4**: Extended position - arm fully extended
5. **Preset 5**: Compact position - arm folded compactly

## 🔧 Testing

### Motor Testing
1. Upload the code
2. Open Serial Monitor (115200 baud)
3. Send `TEST_MOTORS` to test all motors individually
4. Send individual commands like `FORWARD:30` to test movement

### Servo Testing
1. Send `TEST_SERVOS` to test all servos
2. Send `CALIBRATE` to move all servos to 90°
3. Test individual servos with `SERVO1:90`, etc.

### Bluetooth Testing
1. Pair your device with the HC-05/HC-06 module
2. Use a Bluetooth terminal app
3. Send `PING` - should receive `PONG` response
4. Send `HELP` to see all available commands

## 🛡 Safety Features

- **Command timeout**: Motors stop automatically after 2 seconds without commands
- **Emergency stop**: `EMERGENCY` command stops all movement immediately
- **Safe servo positioning**: Prevents dangerous arm positions
- **Memory monitoring**: Warns when memory is low
- **Status LED**: Visual indication of system state
- **Optional emergency button**: Hardware emergency stop

## 🔍 Troubleshooting

### Motors not working
1. Check motor driver connections
2. Verify power supply voltage and current
3. Test with `TEST_MOTORS` command
4. Check motor direction settings in `config.h`

### Servos not responding
1. Verify servo power supply (5V, adequate current)
2. Check servo connections to correct pins
3. Test with `CALIBRATE` command
4. Use `TEST_SERVOS` for individual testing

### Bluetooth connection issues
1. Check HC-05/HC-06 wiring
2. Verify baud rate (9600 default)
3. Test with `PING` command
4. Check pairing status

### System hanging or poor performance
1. Monitor free memory with `STATUS` command
2. Check loop frequency in status output
3. Reduce debug output if memory is low
4. Verify power supply stability

## 📊 Status Monitoring

Send `STATUS` command to get:
- Motor speeds and states
- Servo positions and movement status
- System uptime and memory usage
- Loop frequency and performance metrics
- Emergency stop status

## 🔄 Extending the Code

The modular design makes it easy to add new features:

### Adding New Motor Commands
1. Add command constants to `config.h`
2. Add parsing logic in `command_processor.h`
3. Implement movement function in `motor_controller.h`

### Adding New Servo Presets
1. Add preset logic in `servo_arm.h` `moveToPreset()` function
2. Define new preset positions
3. Add command parsing in `command_processor.h`

### Adding Sensors
1. Create new sensor module header file
2. Add initialization in `main.ino`
3. Add sensor readings to status reporting
4. Integrate sensor data into control logic

### Adding New Communication Methods
1. Create new communication handler (similar to `bluetooth_handler.h`)
2. Modify `command_processor.h` to accept commands from new source
3. Update `main.ino` to initialize new communication module

## 📚 Code Architecture

### Main Components

1. **main.ino**: Entry point that coordinates all subsystems
2. **config.h**: Central configuration and constants
3. **bluetooth_handler.h**: Bluetooth communication management
4. **motor_controller.h**: 4-wheel motor control with safety features
5. **servo_arm.h**: 6-servo arm control with smooth movement
6. **command_processor.h**: Command parsing and routing
7. **system_status.h**: System monitoring and safety management

### Data Flow
```
Bluetooth Input → Command Processor → Motor/Servo Controllers → Hardware
                                  ↓
System Status ← Status Monitoring ←
```

### Safety Layers
- Hardware emergency stop button
- Software command timeouts
- Memory monitoring
- Performance monitoring
- Safe position checking for servos

## 🎮 Example Usage Scenarios

### Basic Movement
```
FORWARD:50        # Move forward at 50% speed
LEFT:30           # Turn left at 30% speed
STOP              # Stop all movement
```

### Arm Operations
```
ARM_HOME          # Move to home position
GRIPPER_OPEN      # Open gripper
ARM_PRESET:1      # Move to pickup position
GRIPPER_CLOSE     # Close gripper
ARM_PRESET:2      # Move to place position
GRIPPER_OPEN      # Release object
ARM_HOME          # Return to home
```

### System Management
```
STATUS            # Check system status
SPEED:80          # Increase motor speed to 80%
SERVO_SPEED:5     # Set fast servo movement
DEBUG:1           # Enable debug output
```

## 🔧 Hardware Tips

### Power Supply Recommendations
- **Arduino**: USB power or 7-12V DC input
- **Motors**: 7-12V, 2-5A depending on motor size
- **Servos**: 5V, 3-6A (500mA per servo minimum)
- **Use separate power supplies** for motors and servos to avoid interference

### Wiring Best Practices
- Use thick wires for motor power connections
- Keep signal wires away from power wires
- Add capacitors across motor terminals to reduce electrical noise
- Use a common ground for all components
- Consider using a power distribution board

### Mechanical Considerations
- Ensure proper mounting of motor drivers for heat dissipation
- Use appropriate gear ratios for your wheel size and desired speed
- Balance the servo arm to reduce stress on servos
- Add mechanical limits to prevent arm over-extension

## 📋 Maintenance

### Regular Checks
- Monitor system status for warnings
- Check connection stability
- Verify servo positions are accurate
- Test emergency stop functionality

### Performance Optimization
- Monitor memory usage over time
- Adjust command timeout values based on usage
- Optimize servo movement speeds for your application
- Calibrate motors and servos periodically

## 🆘 Support

### Debug Information
Enable debug mode with `DEBUG:1` to see detailed operation logs including:
- Command reception and parsing
- Motor speed changes and directions
- Servo position updates
- System status changes
- Error and warning messages

### Common Issues and Solutions

**Issue**: Robot moves in wrong direction
**Solution**: Adjust motor direction constants in `config.h`

**Issue**: Servos jitter or don't hold position
**Solution**: Check power supply capacity and wiring

**Issue**: Bluetooth disconnects frequently
**Solution**: Verify power supply stability and reduce distance

**Issue**: System becomes unresponsive
**Solution**: Check memory usage with `STATUS` command, reduce debug output

**Issue**: Emergency stop doesn't work
**Solution**: Verify emergency button wiring and test with `EMERGENCY` command

## 📜 License

This code is provided as-is for educational and hobbyist use. Feel free to modify and extend for your projects.

## 🤝 Contributing

Suggestions for improvements:
- Additional sensor integration
- More sophisticated movement algorithms
- Enhanced safety features
- Better power management
- Wireless control improvements

---

**Happy building! 🤖**