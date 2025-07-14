#!/usr/bin/env python3
"""
HC Bluetooth Module Diagnostic Tool
Comprehensive diagnostics for HC-05/HC-06 connection issues
"""

import subprocess
import sys
import time
import re
from typing import Dict, List, Any

def run_command(cmd: str) -> str:
    """Run a command and return its output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return "Command timed out"
    except Exception as e:
        return f"Error: {str(e)}"

def check_android_bluetooth() -> Dict[str, Any]:
    """Check Android Bluetooth status using ADB if available"""
    print("📱 Checking Android Bluetooth status...")
    
    results = {}
    
    # Check if ADB is available
    adb_check = run_command("adb version")
    if "Android Debug Bridge" in adb_check:
        results['adb_available'] = True
        
        # Check if device is connected
        devices = run_command("adb devices")
        if "device" in devices and not devices.count('\n') <= 1:
            results['device_connected'] = True
            
            # Check Bluetooth status
            bt_status = run_command("adb shell settings get global bluetooth_on")
            results['bluetooth_enabled'] = bt_status.strip() == "1"
            
            # List paired devices
            paired_cmd = "adb shell dumpsys bluetooth_manager | grep 'mName'"
            paired_devices = run_command(paired_cmd)
            results['paired_devices'] = paired_devices.split('\n') if paired_devices else []
            
        else:
            results['device_connected'] = False
            print("   ⚠️  No Android device connected via ADB")
    else:
        results['adb_available'] = False
        print("   ℹ️  ADB not available - install Android SDK Platform Tools for advanced diagnostics")
    
    return results

def check_hc_module_patterns() -> List[str]:
    """Check for common HC module naming patterns"""
    print("🔍 Searching for HC module patterns...")
    
    # Common HC module names and patterns
    hc_patterns = [
        "HC-05", "HC-06", "HC05", "HC06",
        "ESP32_Robot", "Arduino", "Robot",
        "Bluetooth", "BT", "HC"
    ]
    
    found_patterns = []
    
    # On Windows, try using PowerShell to check Bluetooth devices
    if sys.platform == "win32":
        ps_cmd = 'Get-PnpDevice -Class Bluetooth | Where-Object {$_.Status -eq "OK"} | Select-Object FriendlyName'
        bt_devices = run_command(f'powershell -Command "{ps_cmd}"')
        
        for pattern in hc_patterns:
            if pattern.lower() in bt_devices.lower():
                found_patterns.append(f"Found pattern '{pattern}' in Windows Bluetooth devices")
    
    # On Linux, try bluetoothctl
    elif sys.platform.startswith("linux"):
        paired_devices = run_command("bluetoothctl paired-devices 2>/dev/null")
        for pattern in hc_patterns:
            if pattern.lower() in paired_devices.lower():
                found_patterns.append(f"Found pattern '{pattern}' in paired devices")
    
    return found_patterns

def check_flutter_app_config() -> Dict[str, Any]:
    """Check Flutter app configuration"""
    print("📱 Checking Flutter app configuration...")
    
    results = {}
    
    # Check if Flutter project exists
    pubspec_check = run_command("ls pubspec.yaml 2>/dev/null || dir pubspec.yaml 2>nul")
    if "pubspec.yaml" in pubspec_check:
        results['flutter_project'] = True
        
        # Check for Bluetooth dependencies
        pubspec_content = run_command("cat pubspec.yaml 2>/dev/null || type pubspec.yaml 2>nul")
        if "flutter_bluetooth_serial" in pubspec_content:
            results['bluetooth_dependency'] = True
            print("   ✅ flutter_bluetooth_serial dependency found")
        else:
            results['bluetooth_dependency'] = False
            print("   ❌ flutter_bluetooth_serial dependency missing")
            
        if "permission_handler" in pubspec_content:
            results['permission_dependency'] = True
            print("   ✅ permission_handler dependency found")
        else:
            results['permission_dependency'] = False
            print("   ❌ permission_handler dependency missing")
    else:
        results['flutter_project'] = False
        print("   ⚠️  Not in a Flutter project directory")
    
    return results

def check_arduino_code() -> Dict[str, Any]:
    """Check Arduino code configuration"""
    print("🔧 Checking Arduino code...")
    
    results = {}
    
    # Check for Arduino controller files
    arduino_files = []
    for filename in ["unified_robot_controller.ino", "robot_controller.ino", "wireless-controller.c"]:
        file_check = run_command(f"ls robot_controller/{filename} 2>/dev/null || dir robot_controller\\{filename} 2>nul")
        if filename in file_check:
            arduino_files.append(filename)
    
    results['arduino_files'] = arduino_files
    
    if arduino_files:
        print(f"   ✅ Found Arduino files: {', '.join(arduino_files)}")
        
        # Check unified controller specifically
        if "unified_robot_controller.ino" in arduino_files:
            results['unified_controller'] = True
            print("   ✅ Unified HC-compatible controller found")
        else:
            results['unified_controller'] = False
            print("   ⚠️  Unified controller not found - recommended for HC modules")
    else:
        results['arduino_files'] = []
        print("   ❌ No Arduino controller files found")
    
    return results

def generate_connection_report(android_bt: Dict, hc_patterns: List, flutter_config: Dict, arduino_config: Dict) -> str:
    """Generate a comprehensive connection report"""
    
    report = """
# HC Bluetooth Module Connection Diagnostic Report

## Summary
"""
    
    # Calculate overall health score
    score = 0
    max_score = 10
    
    if android_bt.get('bluetooth_enabled', False):
        score += 2
        report += "✅ Android Bluetooth is enabled\n"
    else:
        report += "❌ Android Bluetooth is disabled or not detected\n"
    
    if hc_patterns:
        score += 2
        report += f"✅ Found HC module patterns: {len(hc_patterns)} matches\n"
    else:
        report += "❌ No HC module patterns detected\n"
    
    if flutter_config.get('bluetooth_dependency', False):
        score += 2
        report += "✅ Flutter Bluetooth dependencies are configured\n"
    else:
        report += "❌ Flutter Bluetooth dependencies missing\n"
    
    if arduino_config.get('unified_controller', False):
        score += 2
        report += "✅ Unified HC-compatible Arduino controller found\n"
    else:
        report += "❌ Unified Arduino controller missing\n"
    
    if android_bt.get('device_connected', False):
        score += 1
        report += "✅ Android device connected via ADB\n"
    
    if flutter_config.get('permission_dependency', False):
        score += 1
        report += "✅ Permission handler configured\n"
    
    health_percentage = (score / max_score) * 100
    report += f"\n**Overall Health Score: {score}/{max_score} ({health_percentage:.0f}%)**\n"
    
    # Recommendations
    report += "\n## Recommendations\n"
    
    if health_percentage < 50:
        report += "🚨 **CRITICAL ISSUES DETECTED**\n"
        report += "Multiple components need attention before HC connection will work.\n\n"
    elif health_percentage < 80:
        report += "⚠️ **SOME ISSUES DETECTED**\n"
        report += "Connection may work but could be unstable.\n\n"
    else:
        report += "✅ **SYSTEM LOOKS GOOD**\n"
        report += "HC Bluetooth connection should work properly.\n\n"
    
    # Specific recommendations
    if not arduino_config.get('unified_controller', False):
        report += "1. **Upload unified_robot_controller.ino to your Arduino**\n"
        report += "   - This controller is specifically designed for HC modules\n"
        report += "   - Uses SoftwareSerial with proper timing\n"
        report += "   - Connect HC module to pins 2 (RX) and 3 (TX)\n\n"
    
    if not flutter_config.get('bluetooth_dependency', False):
        report += "2. **Add Bluetooth dependency to pubspec.yaml**\n"
        report += "   ```yaml\n"
        report += "   dependencies:\n"
        report += "     flutter_bluetooth_serial: ^0.4.0\n"
        report += "   ```\n\n"
    
    if not android_bt.get('bluetooth_enabled', False):
        report += "3. **Enable Bluetooth on Android device**\n"
        report += "   - Go to Settings → Bluetooth\n"
        report += "   - Turn on Bluetooth\n"
        report += "   - Make device discoverable\n\n"
    
    if not hc_patterns:
        report += "4. **Check HC module pairing**\n"
        report += "   - Ensure HC module is powered and blinking\n"
        report += "   - Pair device manually in Android Settings\n"
        report += "   - Default PIN is usually 1234 or 0000\n\n"
    
    # Hardware checklist
    report += "## Hardware Checklist\n"
    report += "- [ ] HC module powered (LED blinking)\n"
    report += "- [ ] Correct voltage (3.3V or 5V depending on module)\n"
    report += "- [ ] TX/RX connections not swapped\n"
    report += "- [ ] GND connected\n"
    report += "- [ ] Arduino running unified_robot_controller.ino\n"
    report += "- [ ] Baud rate set to 9600\n"
    report += "- [ ] Device paired in Android Bluetooth settings\n\n"
    
    # Troubleshooting steps
    report += "## Next Steps\n"
    if health_percentage < 50:
        report += "1. Fix critical issues listed above\n"
        report += "2. Re-run this diagnostic\n"
        report += "3. Test basic pairing in Android settings\n"
        report += "4. Upload unified Arduino controller\n"
        report += "5. Test connection with Flutter app\n"
    else:
        report += "1. Test connection with Flutter app\n"
        report += "2. If connection fails, check Arduino Serial Monitor\n"
        report += "3. Verify commands work via Serial Monitor first\n"
        report += "4. Check connection logs in Flutter app\n"
    
    return report

def main():
    """Main diagnostic function"""
    print("🔧 HC Bluetooth Module Connection Diagnostics")
    print("=" * 50)
    
    # Run all diagnostic checks
    android_bt = check_android_bluetooth()
    hc_patterns = check_hc_module_patterns()
    flutter_config = check_flutter_app_config()
    arduino_config = check_arduino_code()
    
    # Generate and display report
    report = generate_connection_report(android_bt, hc_patterns, flutter_config, arduino_config)
    
    print("\n" + "=" * 50)
    print(report)
    
    # Save report to file
    try:
        with open("hc_bluetooth_diagnostic_report.md", "w") as f:
            f.write(report)
        print("\n📄 Report saved to: hc_bluetooth_diagnostic_report.md")
    except Exception as e:
        print(f"\n⚠️  Could not save report: {e}")
    
    print("\n🔧 Diagnostic complete!")

if __name__ == "__main__":
    main()
