#!/usr/bin/env python3
"""
Network and Bluetooth Diagnostics Script
Helps troubleshoot robot control app connectivity issues
"""

import subprocess
import socket
import time
import requests
from typing import List, Dict, Any
import json

def run_command(cmd: str) -> str:
    """Run a system command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
        return result.stdout.strip()
    except Exception as e:
        return f"Error: {e}"

def check_network_connectivity() -> Dict[str, Any]:
    """Check basic network connectivity"""
    print("🌐 Checking network connectivity...")
    
    results = {}
    
    # Test internet connectivity
    try:
        response = requests.get('https://www.google.com', timeout=5)
        results['internet'] = response.status_code == 200
    except Exception as e:
        results['internet'] = False
        results['internet_error'] = str(e)
    
    # Get local IP address
    try:
        # Connect to a remote address to get local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        results['local_ip'] = local_ip
        results['network_range'] = '.'.join(local_ip.split('.')[:-1]) + '.0/24'
    except Exception as e:
        results['local_ip'] = None
        results['local_ip_error'] = str(e)
    
    # Test DNS resolution
    try:
        socket.gethostbyname('google.com')
        results['dns'] = True
    except Exception as e:
        results['dns'] = False
        results['dns_error'] = str(e)
    
    return results

def scan_for_raspberry_pi() -> List[Dict[str, Any]]:
    """Scan for Raspberry Pi devices on the network"""
    print("🔍 Scanning for Raspberry Pi devices...")
    
    devices = []
    
    # Get local network range
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        
        network_prefix = '.'.join(local_ip.split('.')[:-1])
        
        # Quick scan of common IP ranges
        for i in range(1, 255):
            ip = f"{network_prefix}.{i}"
            
            # Test common Pi services
            pi_indicators = {
                'ssh': test_port(ip, 22, 1),
                'http': test_port(ip, 80, 1),
                'camera': test_port(ip, 8080, 1),
                'vnc': test_port(ip, 5900, 1)
            }
            
            # If any service responds, it might be a Pi
            if any(pi_indicators.values()):
                device = {
                    'ip': ip,
                    'services': pi_indicators,
                    'confidence': sum(pi_indicators.values())
                }
                
                # Test hostname resolution
                try:
                    hostname = socket.gethostbyaddr(ip)[0]
                    device['hostname'] = hostname
                    if any(term in hostname.lower() for term in ['raspberry', 'pi', 'rpi']):
                        device['confidence'] += 2
                except:
                    device['hostname'] = None
                
                devices.append(device)
                print(f"  Found potential Pi at {ip} (confidence: {device['confidence']})")
    
    except Exception as e:
        print(f"❌ Network scan failed: {e}")
    
    return devices

def test_port(ip: str, port: int, timeout: int = 3) -> bool:
    """Test if a port is open on an IP address"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((ip, port))
        sock.close()
        return result == 0
    except:
        return False

def test_camera_servers(devices: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Test camera server endpoints on discovered devices"""
    print("📹 Testing camera server endpoints...")
    
    camera_servers = []
    
    for device in devices:
        ip = device['ip']
        
        # Test common camera endpoints
        endpoints = [
            'video_feed',
            'stream',
            'camera',
            'mjpeg',
            'my_mac_camera',
            ''
        ]
        
        ports = [8080, 8081, 5000, 8000, 80]
        
        for port in ports:
            if device['services'].get('camera' if port == 8080 else 'http', False):
                for endpoint in endpoints:
                    url = f"http://{ip}:{port}"
                    if endpoint:
                        url += f"/{endpoint}"
                    
                    try:
                        response = requests.get(url, timeout=3)
                        if response.status_code == 200:
                            camera_servers.append({
                                'ip': ip,
                                'port': port,
                                'endpoint': endpoint,
                                'url': url,
                                'confidence': device['confidence']
                            })
                            print(f"  ✅ Camera server found: {url}")
                    except:
                        pass
    
    return camera_servers

def check_bluetooth_status() -> Dict[str, Any]:
    """Check Bluetooth status and paired devices"""
    print("📱 Checking Bluetooth status...")
    
    results = {}
    
    # Check Bluetooth service (Linux/Mac)
    bt_status = run_command("systemctl is-active bluetooth 2>/dev/null || echo 'unknown'")
    results['service_status'] = bt_status
    
    # Check if Bluetooth is enabled
    hci_status = run_command("hciconfig 2>/dev/null | grep -o 'UP RUNNING' | head -1")
    results['interface_up'] = 'UP RUNNING' in hci_status
    
    # List paired devices
    paired_devices = run_command("bluetoothctl paired-devices 2>/dev/null")
    results['paired_devices'] = paired_devices.split('\n') if paired_devices else []
    
    # Check for common robot device names
    robot_patterns = ['HC-', 'robot', 'arduino', 'esp', 'bluetooth']
    results['robot_devices'] = []
    
    for device in results['paired_devices']:
        if any(pattern.lower() in device.lower() for pattern in robot_patterns):
            results['robot_devices'].append(device)
    
    return results

def generate_report(network_results: Dict[str, Any], 
                   pi_devices: List[Dict[str, Any]], 
                   camera_servers: List[Dict[str, Any]],
                   bluetooth_results: Dict[str, Any]) -> str:
    """Generate a comprehensive diagnostic report"""
    
    report = []
    report.append("=" * 60)
    report.append("🤖 ROBOT CONTROL APP DIAGNOSTICS REPORT")
    report.append("=" * 60)
    report.append("")
    
    # Network Status
    report.append("🌐 NETWORK STATUS")
    report.append("-" * 30)
    report.append(f"Internet: {'✅ Connected' if network_results.get('internet') else '❌ Disconnected'}")
    report.append(f"DNS: {'✅ Working' if network_results.get('dns') else '❌ Failed'}")
    report.append(f"Local IP: {network_results.get('local_ip', 'Unknown')}")
    report.append(f"Network Range: {network_results.get('network_range', 'Unknown')}")
    report.append("")
    
    # Raspberry Pi Devices
    report.append(f"🔍 RASPBERRY PI DEVICES ({len(pi_devices)} found)")
    report.append("-" * 30)
    
    if pi_devices:
        for device in sorted(pi_devices, key=lambda x: x['confidence'], reverse=True):
            confidence = "High" if device['confidence'] >= 3 else "Medium" if device['confidence'] >= 2 else "Low"
            report.append(f"IP: {device['ip']} (Confidence: {confidence})")
            report.append(f"  Hostname: {device.get('hostname', 'Unknown')}")
            
            services = []
            for service, available in device['services'].items():
                if available:
                    services.append(f"✅ {service}")
                else:
                    services.append(f"❌ {service}")
            
            report.append(f"  Services: {', '.join(services)}")
            report.append("")
    else:
        report.append("No Raspberry Pi devices found")
        report.append("")
    
    # Camera Servers
    report.append(f"📹 CAMERA SERVERS ({len(camera_servers)} found)")
    report.append("-" * 30)
    
    if camera_servers:
        for server in sorted(camera_servers, key=lambda x: x['confidence'], reverse=True):
            confidence = "High" if server['confidence'] >= 3 else "Medium" if server['confidence'] >= 2 else "Low"
            report.append(f"URL: {server['url']} (Confidence: {confidence})")
            report.append(f"  IP: {server['ip']}, Port: {server['port']}, Endpoint: {server['endpoint']}")
            report.append("")
    else:
        report.append("No camera servers found")
        report.append("")
    
    # Bluetooth Status
    report.append("📱 BLUETOOTH STATUS")
    report.append("-" * 30)
    report.append(f"Service: {bluetooth_results.get('service_status', 'Unknown')}")
    report.append(f"Interface: {'✅ Up' if bluetooth_results.get('interface_up') else '❌ Down'}")
    report.append(f"Paired Devices: {len(bluetooth_results.get('paired_devices', []))}")
    report.append(f"Robot Devices: {len(bluetooth_results.get('robot_devices', []))}")
    
    if bluetooth_results.get('robot_devices'):
        report.append("Robot-like devices:")
        for device in bluetooth_results['robot_devices']:
            report.append(f"  - {device}")
    
    report.append("")
    
    # Recommendations
    report.append("💡 RECOMMENDATIONS")
    report.append("-" * 30)
    
    if not network_results.get('internet'):
        report.append("❌ No internet connection - check WiFi/ethernet")
    
    if not pi_devices:
        report.append("❌ No Raspberry Pi devices found:")
        report.append("  - Ensure Pi is powered on and connected to same network")
        report.append("  - Check Pi's IP address manually")
        report.append("  - Verify SSH/HTTP services are running on Pi")
    
    if not camera_servers:
        report.append("❌ No camera servers found:")
        report.append("  - Start camera server on Raspberry Pi: python server.py")
        report.append("  - Check if camera is connected to Pi")
        report.append("  - Verify firewall allows port 8080")
    
    if not bluetooth_results.get('interface_up'):
        report.append("❌ Bluetooth interface down:")
        report.append("  - Enable Bluetooth on your device")
        report.append("  - Check Bluetooth permissions in app settings")
    
    if not bluetooth_results.get('robot_devices'):
        report.append("❌ No robot devices paired:")
        report.append("  - Pair robot's Bluetooth module in system settings")
        report.append("  - Ensure robot is in pairing mode")
    
    report.append("")
    report.append("=" * 60)
    report.append("Report generated at: " + time.strftime("%Y-%m-%d %H:%M:%S"))
    report.append("=" * 60)
    
    return '\n'.join(report)

def main():
    """Main diagnostic function"""
    print("🚀 Starting Robot Control App Diagnostics...")
    print()
    
    # Run all diagnostics
    network_results = check_network_connectivity()
    pi_devices = scan_for_raspberry_pi()
    camera_servers = test_camera_servers(pi_devices)
    bluetooth_results = check_bluetooth_status()
    
    # Generate report
    report = generate_report(network_results, pi_devices, camera_servers, bluetooth_results)
    
    # Save report
    with open('robot_diagnostics_report.txt', 'w') as f:
        f.write(report)
    
    print(report)
    print()
    print("📄 Full report saved to: robot_diagnostics_report.txt")
    
    # Quick summary for urgent issues
    issues = []
    if not network_results.get('internet'):
        issues.append("No internet connection")
    if not pi_devices:
        issues.append("No Raspberry Pi devices found")
    if not camera_servers:
        issues.append("No camera servers found")
    if not bluetooth_results.get('interface_up'):
        issues.append("Bluetooth interface down")
    
    if issues:
        print()
        print("🚨 URGENT ISSUES DETECTED:")
        for issue in issues:
            print(f"  - {issue}")
        print()
        print("💡 Run this script again after fixing these issues")
    else:
        print()
        print("✅ All systems appear to be working correctly!")

if __name__ == "__main__":
    main()
