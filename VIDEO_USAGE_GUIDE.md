# 🎥 Video Feed Auto-Discovery Usage Guide

## 🚀 Quick Start

### Step 1: Run Auto-Discovery

```bash
# Windows - Easy mode
quick_scan.bat

# Or run manually
python quick_scan.py
```

### Step 2: Review Results

The tool will show you:

- 📍 Active devices on your network
- 🍓 Identified Raspberry Pi devices
- 📹 Found camera servers with confidence levels
- 🎯 Recommended camera server URL

### Step 3: Update Your Flutter App

If a camera server is found, update your Flutter app configuration:

```dart
// In your video service initialization
final videoService = VideoService(
  raspberryPiIP: 'DISCOVERED_IP',    // e.g., '192.168.1.100'
  port: DISCOVERED_PORT,             // e.g., 8080
  endpoint: 'DISCOVERED_ENDPOINT',   // e.g., 'my_mac_camera'
);
```

## 🔧 Advanced Usage

### Full Diagnostic Mode

```bash
# Windows
diagnose_camera.bat

# Mac/Linux
python test_camera_server.py
```

### Manual Testing

```bash
# Test specific IP
python -c "
import requests
response = requests.get('http://192.168.1.8:8080/my_mac_camera', timeout=5)
print(f'Status: {response.status_code}')
print(f'Content-Type: {response.headers.get(\"content-type\", \"unknown\")}')
"
```

## 📊 Understanding Results

### Confidence Levels

- **High Confidence** (3+ indicators): Very likely a Raspberry Pi with camera
- **Medium Confidence** (2 indicators): Probably a Pi device
- **Low Confidence** (1 indicator): Camera server found but device type unclear

### Common Indicators

- ✅ **SSH (Port 22)** - Remote access enabled
- ✅ **HTTP (Port 80)** - Web server running
- ✅ **Camera (Port 8080)** - Video streaming service
- ✅ **VNC (Port 5900)** - Remote desktop access
- ✅ **Hostname** - Contains "raspberry", "pi", or "rpi"

## 🎯 Troubleshooting

### No Servers Found

1. Check if camera server is running: `python server.py`
2. Ensure both devices are on same network
3. Verify firewall settings
4. Try manual IP configuration

### Multiple Servers Found

1. Use the one with highest confidence
2. Test each URL in your browser
3. Check which responds with video stream
4. Update Flutter app with the working URL

### Server Found But Not Working

1. Test URL in browser: `http://IP:PORT/ENDPOINT`
2. Check camera server logs for errors
3. Verify camera is not used by another app
4. Try different camera index in server.py

## 📱 Flutter Integration

The Flutter app now includes auto-discovery. To use it:

```dart
// Initialize with auto-discovery
final videoState = await videoService.initializeVideoFeedWithDiscovery();

if (videoState.isActive) {
  print('✅ Video feed active');
} else {
  print('❌ Video feed failed: ${videoState.errorMessage}');
}
```

## 🛠️ Files Created

- `test_camera_server.py` - Full diagnostic script
- `quick_scan.py` - Quick auto-discovery
- `diagnose_camera.bat` - Windows batch file
- `quick_scan.bat` - Windows quick scan
- `CAMERA_TROUBLESHOOTING.md` - Detailed troubleshooting guide

## 🔄 Next Steps

1. Run the auto-discovery tool
2. Note the recommended camera server URL
3. Update your Flutter app configuration
4. Test the video feed in your app
5. If issues persist, check the full troubleshooting guide

Happy streaming! 🎬
