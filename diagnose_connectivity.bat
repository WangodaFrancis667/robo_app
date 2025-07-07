@echo off
echo 🚀 Robot Control App Diagnostics
echo ================================
echo.
echo This script will help diagnose connectivity issues with your robot control app.
echo It will check:
echo - Network connectivity
echo - Raspberry Pi device discovery
echo - Camera server availability
echo - Bluetooth status
echo.
pause
echo.
echo 🔍 Running diagnostics...
echo.

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python not found. Please install Python 3.6+ and try again.
    pause
    exit /b 1
)

REM Install required packages
echo 📦 Installing required packages...
pip install requests >nul 2>&1

REM Run the diagnostic script
python diagnose_connectivity.py

echo.
echo 📄 Check the generated report: robot_diagnostics_report.txt
echo.
echo 💡 If issues are found, refer to the troubleshooting guide:
echo    CAMERA_TROUBLESHOOTING.md
echo.
pause
