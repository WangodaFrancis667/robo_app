# HC Bluetooth Module Connection Guide

## Hardware Setup for HC-05/HC-06 Modules

### Pin Connections (Arduino Uno/Nano/Mega)

```
HC-05/HC-06 Module → Arduino
VCC (3.3V or 5V)   → 5V (or 3.3V)
GND                 → GND
TXD                 → Pin 2 (Software Serial RX)
RXD                 → Pin 3 (Software Serial TX)
```

### Important Notes:

- Use SoftwareSerial library for HC modules
- HC-05/HC-06 default baud rate is usually 9600
- Some modules require 3.3V, others work with 5V
- Connect RXD through a voltage divider if using 5V Arduino

## HC Module Configuration

### AT Commands Setup (Optional)

If you need to configure your HC module:

1. **Enter AT mode:**

   - Power on the module while holding the button (HC-05)
   - LED should blink slowly (every 2 seconds)

2. **Common AT Commands:**
   ```
   AT                    → Test connection
   AT+NAME=ESP32_Robot   → Set device name
   AT+PSWD=1234         → Set pairing password
   AT+UART=9600,0,0     → Set baud rate
   ```

## Troubleshooting Steps

### 1. Check Hardware Connections

- Ensure VCC is connected to correct voltage (3.3V or 5V)
- Verify GND connection
- Confirm TX/RX are not swapped
- Check for loose connections

### 2. Verify Module Power

- HC module LED should be blinking
- If LED is solid, module may be paired but not connected
- If no LED, check power connections

### 3. Test with Serial Monitor

Upload the unified_robot_controller.ino and:

- Open Serial Monitor at 115200 baud
- Type commands like "PING" or "STATUS"
- Should see responses in Serial Monitor

### 4. Pairing Issues

If Android can't find the device:

- Reset HC module (power cycle)
- Clear Android Bluetooth cache
- Search for devices in Android Settings → Bluetooth
- Look for device name (default: HC-05 or HC-06)

### 5. Connection Drops

If connection establishes but drops immediately:

- Ensure Arduino code is uploaded and running
- Check for power issues (insufficient current)
- Verify baud rate matches (9600)
- Try shorter commands initially

## Code Implementation

### Arduino Side (unified_robot_controller.ino)

```cpp
#include <SoftwareSerial.h>

#define BT_RX_PIN 2
#define BT_TX_PIN 3
#define BT_BAUD_RATE 9600

SoftwareSerial bluetooth(BT_RX_PIN, BT_TX_PIN);

void setup() {
  Serial.begin(115200);
  bluetooth.begin(BT_BAUD_RATE);
  Serial.println("HC Bluetooth Ready");
  bluetooth.println("ROBOT_READY");
}

void loop() {
  // Handle bluetooth commands
  if (bluetooth.available()) {
    String command = bluetooth.readStringUntil('\n');
    processCommand(command);
  }
}
```

### Flutter App Side

The app has been updated with:

- Reduced connection stability testing
- Longer delays between commands
- Less aggressive connection monitoring
- HC-specific command timeouts

## Expected Behavior

### Successful Connection:

1. HC module LED blinks (searching)
2. Android finds device in Bluetooth settings
3. Pair device (may require PIN: 1234 or 0000)
4. App connects successfully
5. HC module LED becomes solid (connected)
6. Commands work properly

### Commands Testing:

- `PING` → Should return `PONG`
- `STATUS` → Should return system status
- `F:50` → Move forward at 50% speed
- `STOP` → Stop all motors

## Common Issues and Solutions

### Issue: "Device not found"

**Solution:**

- Ensure HC module is powered and blinking
- Check pairing in Android Bluetooth settings first
- Try moving closer to HC module

### Issue: "Connection timeout"

**Solution:**

- Check Arduino code is uploaded and running
- Verify baud rate is 9600 in both Arduino and HC module
- Try power cycling the HC module

### Issue: "Commands not working"

**Solution:**

- Test with Serial Monitor first
- Check command format (use uppercase)
- Ensure Arduino is processing bluetooth.available()
- Verify motor driver connections

### Issue: "Connection drops immediately"

**Solution:**

- This was a major issue - now fixed in code
- App no longer does aggressive stability testing
- Increased delays between commands
- Reduced connection monitoring frequency

## Testing Checklist

- [ ] HC module LED is blinking when powered
- [ ] Module appears in Android Bluetooth settings
- [ ] Can pair successfully with Android
- [ ] Arduino code uploaded and Serial Monitor shows "HC Bluetooth Ready"
- [ ] App finds device in bonded devices list
- [ ] Connection establishes without immediate drop
- [ ] Can send basic commands (PING, STATUS)
- [ ] Motor commands work (F:50, STOP)

## Hardware Shopping List

For HC-05 setup:

- HC-05 Bluetooth module
- Arduino Uno/Nano/Mega
- Motor driver (L298N recommended)
- DC motors
- Jumper wires
- Power supply (7-12V for motors)
- Breadboard or PCB for connections

The unified controller code provides better compatibility with HC modules and the Flutter app now handles HC-specific timing requirements.
