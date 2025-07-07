#!/usr/bin/env python3
"""
Quick Camera Server Auto-Discovery Test
This script demonstrates the auto-discovery functionality.
"""
import subprocess
import sys
import os

def run_diagnostic():
    """Run the full diagnostic script"""
    script_path = os.path.join(os.path.dirname(__file__), 'test_camera_server.py')
    
    try:
        print("🚀 Running Camera Server Auto-Discovery...")
        print("=" * 60)
        
        result = subprocess.run([sys.executable, script_path], 
                              capture_output=False, 
                              text=True)
        
        return result.returncode == 0
        
    except Exception as e:
        print(f"❌ Failed to run diagnostic: {e}")
        return False

def main():
    print("🎥 Quick Camera Server Auto-Discovery Test")
    print("=" * 60)
    print()
    
    print("This script will:")
    print("1. 🔍 Scan your local network for active hosts")
    print("2. 🍓 Identify potential Raspberry Pi devices")
    print("3. 📹 Search for camera servers on those devices")
    print("4. 🎯 Provide recommendations for your Flutter app")
    print()
    
    input("Press Enter to start the scan...")
    print()
    
    success = run_diagnostic()
    
    print()
    print("=" * 60)
    
    if success:
        print("✅ Auto-discovery completed successfully!")
        print()
        print("📱 Next steps:")
        print("1. Check the output above for discovered camera servers")
        print("2. Update your Flutter app with the recommended URL")
        print("3. Test the camera feed in your app")
    else:
        print("⚠️  Auto-discovery completed with warnings")
        print()
        print("🔧 Troubleshooting:")
        print("1. Make sure your camera server is running: python server.py")
        print("2. Check that both devices are on the same network")
        print("3. Verify firewall settings are not blocking connections")
    
    print()
    input("Press Enter to exit...")

if __name__ == "__main__":
    main()
