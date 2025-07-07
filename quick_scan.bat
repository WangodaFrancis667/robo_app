@echo off
echo.
echo 🎥 Quick Camera Server Auto-Discovery
echo ====================================
echo.
echo This tool will automatically scan your network for Raspberry Pi
echo devices and camera servers to help fix your video feed issue.
echo.
echo Please make sure:
echo - Your camera server is running (python server.py)
echo - Both devices are on the same network
echo - Firewall allows network scanning
echo.
pause
echo.
echo 🚀 Starting auto-discovery scan...
echo.

python quick_scan.py

echo.
echo 📋 Scan complete!
echo.
pause
