# HC-05/HC-06 Bluetooth Module Connection Troubleshooting Guide

If you're experiencing issues connecting to your HC-05 or HC-06 Bluetooth module from the Robo App, try these troubleshooting steps.

## Common Errors

### "read failed, socket might closed or timeout, read ret: -1"

This is a common error with HC-05/HC-06 modules that occurs when the Android Bluetooth stack cannot establish a stable connection.

### Connection timeouts

Timeouts usually indicate communication issues between your phone and the HC module.

## Step-by-Step Troubleshooting

### 1. Check HC Module Hardware

- **Power Supply**: Ensure your HC module is receiving stable 3.3V or 5V power (as required by your model)
- **LED Status**: The LED should blink when unpaired, and become solid when connected
- **Physical Connections**: Check all wires and connections to your Arduino/ESP32/microcontroller

### 2. Check Arduino/Microcontroller Setup

- **Baud Rate**: Ensure your code uses the correct baud rate (typically 9600 for HC modules)
- **TX/RX Pins**: Confirm TX from Arduino connects to RX on HC module, and RX from Arduino to TX on HC module
- **Upload Latest Code**: Make sure you've uploaded the most recent firmware to your microcontroller

### 3. Android Bluetooth Settings

- **Forget & Re-Pair**: Go to Android Bluetooth settings, forget the HC module, then pair it again
- **Default PIN**: The default pairing PIN is usually `1234` or `0000`
- **Restart Bluetooth**: Toggle Bluetooth off and on in your Android settings
- **Restart Device**: Sometimes a full phone restart can fix Bluetooth stack issues

### 4. App Connection Settings

- **Permissions**: Make sure you've granted all Bluetooth and Location permissions to the app
- **Connection Timeout**: Try increasing the connection timeout in app settings (if available)
- **Alternative Connection Methods**: Use the "Alternative Connection" option in the app (if available)

### 5. Advanced Troubleshooting

- **AT Command Mode**: You can configure your HC module using AT commands:
  1. Disconnect any existing connections
  2. Connect KEY pin to VCC (for HC-05)
  3. Power cycle the module
  4. Send `AT` (should respond with `OK`)
  5. Send `AT+VERSION` to check the firmware version
  6. Send `AT+UART=9600,0,0` to set baud rate to 9600
  7. Send `AT+ROLE=0` to set as slave mode (for most robot applications)
  8. Power cycle the module again

- **Distance**: Try keeping your phone closer to the HC module during connection
- **Interference**: Move away from other Bluetooth or 2.4GHz devices
- **Module Replacement**: If nothing else works, the module might be faulty and need replacement

## Debug Steps When Error Occurs

1. Check if the HC module LED is blinking or solid
2. Verify your Arduino is powered and running correctly
3. Try connecting with a different phone if possible
4. Power cycle both the HC module and your phone
5. Use the in-app diagnostic tool to get detailed error information

## App Specific Settings

- Use "Advanced Connection Mode" in the app settings
- Try increasing the connection timeout to 30 seconds
- Enable "Connection Retry" feature
- If available, try the "HC-05 Compatibility Mode"

Remember, HC-05/HC-06 modules can be finicky with Android Bluetooth connections. Sometimes it takes a few tries to establish a stable connection.
