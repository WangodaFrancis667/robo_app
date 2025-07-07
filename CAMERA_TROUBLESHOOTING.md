# 🎥 Camera Server Troubleshooting Guide

## Problem: Video Feed Not Displaying

The video feed is showing timeout errors because the camera server at `http://192.168.1.8:8080/my_mac_camera` is not accessible.

## Quick Diagnostics

### 1. Quick Auto-Discovery Scan

```bash
# Windows (Easy mode)
quick_scan.bat

# Manual execution
python quick_scan.py
```

### 2. Full Diagnostic Tool

```bash
# On Windows
diagnose_camera.bat

# On Mac/Linux
python test_camera_server.py
```

### 3. Check Camera Server Status

Make sure the camera server is running:

```bash
python server.py
```

You should see output like:

```
Initializing camera...
Camera opened successfully
MJPEG stream available at http://YOUR_MAC_IP:8080/my_mac_camera
Camera streaming started...
```

### 3. Test in Browser

Open the stream URL in your browser:

```
http://192.168.1.8:8080/my_mac_camera
```

If working, you should see the live camera feed.

## Common Issues & Solutions

### Issue 1: Camera Server Not Running

**Solution:** Start the camera server

```bash
cd /path/to/robo_app
python server.py
```

### Issue 2: Wrong IP Address

**Solution:** Find the correct IP address

```bash
# Windows
ipconfig

# Mac/Linux
ifconfig
```

Update the IP in your Flutter app or use the IP scanner tool.

### Issue 3: Network Connectivity

**Solution:** Ensure both devices are on the same network

- Check WiFi connection
- Disable firewall temporarily to test
- Test with ping: `ping 192.168.1.8`

### Issue 4: Port Blocked

**Solution:** Check if port 8080 is blocked

- Test with telnet: `telnet 192.168.1.8 8080`
- Check firewall settings
- Try different port in `server.py`

### Issue 5: Camera Not Found

**Solution:** Check camera permissions and availability

- Ensure camera is not used by another app
- Check camera permissions
- Try different camera index in `server.py`: `cv2.VideoCapture(1)`

## Debugging Steps

1. **Check Server Logs:** Look for error messages when starting `server.py`
2. **Test Network:** Use the diagnostic tool to scan for servers
3. **Browser Test:** Verify the stream works in a web browser
4. **Flutter Logs:** Check Flutter console for detailed error messages
5. **IP Discovery:** Use the IP scanner to find active camera servers

## Updated Features

The video service now includes:

- ✅ Better error messages with troubleshooting tips
- ✅ Extended timeout handling
- ✅ Network diagnostics
- ✅ IP address scanning
- ✅ Improved logging and debugging

## 🚀 New Auto-Discovery Features

The diagnostic tools now include automatic network scanning and Raspberry Pi detection:

### Auto-Discovery Process

1. **Network Scanning** - Automatically detects your local network range
2. **Host Discovery** - Ping sweep to find active devices
3. **Raspberry Pi Detection** - Identifies likely Pi devices by checking common services
4. **Camera Server Scanning** - Tests multiple ports and endpoints for camera streams
5. **Confidence Scoring** - Ranks discoveries by likelihood of being your camera server

### What Gets Detected

- **SSH servers** (port 22) - Common on Raspberry Pi
- **HTTP servers** (port 80) - May indicate Pi web interface
- **Camera servers** (port 8080, 8081, 8000, 5000) - Video streaming services
- **VNC servers** (port 5900) - Remote desktop access
- **Device hostnames** - Looking for "raspberry", "pi", or "rpi" in names

### Discovery Results

The tool will show:

- **High Confidence** - Multiple Pi indicators found
- **Medium Confidence** - Some Pi indicators found  
- **Low Confidence** - Camera server found but no Pi indicators

### Integration with Flutter App

Your Flutter app can now:

- Automatically discover camera servers on startup
- Fall back to manual configuration if auto-discovery fails
- Update video service configuration with discovered servers
- Provide better error messages with troubleshooting tips

## Configuration Options

You can customize the camera server settings in `server.py`:

```python
# Change IP binding (0.0.0.0 for all interfaces)
server = MjpegServer("0.0.0.0", 8080)

# Change camera index
cap = cv2.VideoCapture(0)  # Try 0, 1, 2, etc.

# Change stream endpoint
stream = Stream("my_mac_camera", size=(640, 480), quality=70, fps=20)
```

## Need Help?

If you're still having issues:

1. Run the diagnostic tool: `diagnose_camera.bat`
2. Check the console output for specific error messages
3. Verify network connectivity between devices
4. Test the camera server independently in a browser

The improved error handling will now provide more specific troubleshooting information directly in the Flutter app.
