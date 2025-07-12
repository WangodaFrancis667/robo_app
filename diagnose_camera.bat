@echo off
echo 🎥 Camera Server Diagnostic Tool
echo ================================
echo.
echo This tool will help diagnose camera server connectivity issues.
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Python is not installed or not in PATH
    echo Please install Python and try again
    pause
    exit /b 1
)

REM Check if requests module is available
python -c "import requests" >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  Installing required Python packages...
    python -m pip install requests
    if %errorlevel% neq 0 (
        echo ❌ Failed to install required packages
        echo Please run: pip install requests
        pause
        exit /b 1
    )
)

echo ✅ Running camera server diagnostics...
echo.
python test_camera_server.py
echo.
echo 📋 Diagnostic complete. Check the output above for results.
pause
