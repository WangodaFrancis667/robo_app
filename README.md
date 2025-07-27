# Smart Weeding Robot Control System 🤖

A comprehensive Flutter mobile application for controlling a 4-wheel drive robot with a 6-servo robotic arm, designed for autonomous weeding operations. The system includes real-time video monitoring, Bluetooth communication, collision avoidance, and precision arm control.

## 👥 Development Team

This project was developed by Makerere university students from Uganda:

| Name | Registration No. | Student No. |
|------|------------------|-------------|
| Wangoda Francis | 24/U/11855/PS | 2400711855 |
| Mujuni Innocent | 24/U/07155/PS | 2400707155 |
| Namuli Angel Rebecca | 24/U/09332/PS | 2400709332 |
| Bwanika Robert | 24/U/23908/PSA | 2400723908 |
| Nalugo Linda | 24/U/24447/PS | 2400724447 |

## 🌟 Features

### 🎮 Robot Control

- **4WD Motor Control**: Precise movement with forward, backward, left, right, and tank drive modes
- **6-Servo Robotic Arm**: Full 6-DOF arm control with gripper for precision weeding operations
- **Multiple Control Modes**: Driving mode and arm control mode with intuitive joystick interfaces
- **Emergency Safety Features**: Emergency stop, collision avoidance, and safety timeouts

### 📱 Mobile App Features

- **Real-time Video Feed**: Live camera stream from robot's onboard camera system
- **Bluetooth Connectivity**: Seamless connection to HC-05/HC-06 modules with device pairing
- **Sensor Dashboard**: Real-time monitoring of ultrasonic sensors and system status
- **Weeding Logs**: Track and log weeding operations and robot activities
- **Responsive UI**: Adaptive interface that switches to landscape mode during robot control

### 🛡️ Safety & Monitoring

- **Collision Avoidance**: HC-SR04 ultrasonic sensors prevent collisions
- **System Status Monitoring**: Real-time feedback on motor speeds, servo positions, and system health
- **Memory Optimization**: Efficient Arduino firmware with automatic memory management
- **Command Validation**: Input validation and error handling for reliable operation

### 🔧 Hardware Integration

- **Arduino Mega 2560**: Main controller with modular firmware architecture
- **Dual Motor Drivers**: L298N-compatible drivers for 4-wheel independent control
- **6-Servo Arm**: MG996R servos with smooth movement and preset positions
- **Camera System**: Integration with Raspberry Pi camera for live monitoring
- **Wireless Communication**: Bluetooth and Wi-Fi connectivity options

## 📁 Project Structure

```text
robo_app/
├── lib/                          # Flutter application code
│   ├── main.dart                 # App entry point
│   ├── screens/                  # UI screens
│   │   ├── Dashboard/            # Main dashboard and navigation
│   │   ├── controls/             # Robot control interface
│   │   ├── live_feed/           # Video monitoring
│   │   ├── sensors/             # Sensor dashboard
│   │   └── logs/                # Activity logging
│   ├── utils/                   # Utilities and helpers
│   └── views/                   # HTML views for system monitoring
├── arduino_code/                # Arduino firmware
│   ├── robot_controller.ino     # Main Arduino controller
│   ├── config.h                 # Hardware configuration
│   ├── bluetooth_handler.h      # Bluetooth communication
│   ├── motor_controller.h       # 4-wheel motor control
│   ├── servo_arm.h              # 6-servo arm control
│   ├── sensor_manager.h         # Sensor management
│   ├── collision_avoidance.h    # Safety systems
│   └── README.md                # Arduino setup guide
└── assets/                      # App icons and resources
```

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** (3.8.1 or higher)
- **Arduino IDE** for firmware programming
- **Android Studio** or **VS Code** for development
- **Arduino Mega 2560** with required hardware components

### Hardware Requirements

- Arduino Mega 2560
- 2x L298N Motor Driver modules
- 4x DC motors for wheels
- 6x Servo motors (MG996R recommended)
- HC-05/HC-06 Bluetooth module
- 2x HC-SR04 Ultrasonic sensors
- Camera module (Raspberry Pi camera or USB camera)
- Appropriate power supplies (7-12V for motors, 5V for servos)

### Flutter App Setup

1. **Clone the repository**

   ```bash
   git clone <repository-url>
   cd robo_app
   ```

2. **Install dependencies**

   ```bash
   flutter pub get
   ```

3. **Configure the app**
   - Update IP addresses in `live_monitoring_screen.dart` for your camera server
   - Ensure Bluetooth permissions are granted on Android

4. **Run the application**

   ```bash
   flutter run
   ```

### Arduino Firmware Setup

1. **Open Arduino IDE**
2. **Install required libraries**:
   - Servo library (included with Arduino IDE)
3. **Configure hardware pins** in `arduino_code/config.h`
4. **Upload firmware** to Arduino Mega 2560
5. **Pair Bluetooth module** with your mobile device

## 🎯 Usage

### Basic Operation

1. **Power on the robot** and ensure all systems are connected
2. **Launch the mobile app** and navigate to Robot Control
3. **Pair with Bluetooth device** (look for HC-05 or robot-named devices)
4. **Connect to the robot** - app will switch to landscape control mode
5. **Use joystick controls** for movement and arm operations
6. **Monitor video feed** for real-time visual feedback

### Control Modes

- **Driving Mode**: Control robot movement with virtual joystick
- **Arm Control Mode**: Operate the 6-servo robotic arm for precision tasks
- **Emergency Stop**: Red button for immediate safety shutdown

### Weeding Operations

1. Navigate robot to target area using camera feed
2. Switch to arm control mode
3. Use preset positions for efficient weeding motions
4. Monitor sensor data for obstacle avoidance
5. Log operations in the weeding logs section

## 🔧 Configuration

### Arduino Configuration

Edit `arduino_code/config.h` to customize:

- Pin assignments for motors and servos
- Sensor thresholds and safety parameters
- Bluetooth communication settings
- Debug output levels

### App Configuration

- Update camera server URLs in monitoring screen
- Modify Bluetooth device recognition patterns
- Adjust joystick sensitivity and response curves

## 🛠️ Development

### Key Dependencies

- `flutter_bluetooth_serial`: Bluetooth communication
- `flutter_mjpeg`: Video streaming
- `flutter_vlc_player`: Advanced video playback
- `flutter_joystick`: Touch controls
- `http`: Network communication
- `permission_handler`: Android permissions

### Architecture

- **Modular Design**: Separate modules for different robot functions
- **Safety-First**: Multiple layers of safety checks and emergency stops
- **Real-time Communication**: Efficient command protocol between app and Arduino
- **Memory Optimized**: Careful memory management for stable Arduino operation

## 🔍 Troubleshooting

### Common Issues

- **Bluetooth Connection**: Ensure HC-05 is paired and in range
- **Video Feed**: Check camera server IP and network connectivity
- **Motor Issues**: Verify motor driver connections and power supply
- **Servo Problems**: Check servo power supply (5V, adequate current)

### Debug Features

- Enable debug mode with `DEBUG:1` command via Bluetooth
- Monitor system status through sensor dashboard
- Check Arduino serial output for detailed diagnostics

## 📚 Documentation

- [Arduino Firmware Guide](arduino_code/README.md) - Detailed hardware setup and Arduino programming
- [Flutter-Arduino Protocol](FLUTTER_ARDUINO_PROTOCOL_ALIGNMENT.md) - Communication protocol specification
- [Memory Optimization Report](MEMORY_OPTIMIZATION_REPORT.md) - Performance optimization details

## 🤝 Contributing

Contributions are welcome! Areas for improvement:

- Additional sensor integration
- Enhanced autonomous navigation
- Improved user interface features
- Advanced weeding algorithms
- Power management optimization

## 📞 Contact Information

- **Location**: Kampala, Uganda
- **Phone**: +256 771858922
- **Email**: [fwangoda@gmail.com](mailto:fwangoda@gmail.com)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

We welcome contributions to improve the project website. Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add new feature'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Create a Pull Request

## 🙏 Acknowledgments

- University of `Makerere University Uganda` for project support
- Agricultural community in Uganda for feedback and testing
- Open source community for tools and resources
