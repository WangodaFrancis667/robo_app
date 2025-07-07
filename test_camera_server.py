#!/usr/bin/env python3
"""
Camera Server Test Script
This script helps diagnose camera server connectivity issues.
"""
import requests
import socket
import time
import subprocess
import sys
import threading
import ipaddress
import platform
from urllib.parse import urlparse
from concurrent.futures import ThreadPoolExecutor, as_completed

def test_ip_connectivity(ip, port=8080):
    """Test basic IP connectivity"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((ip, port))
        sock.close()
        return result == 0
    except Exception as e:
        print(f"❌ Socket test failed for {ip}:{port} - {e}")
        return False

def test_http_connectivity(url):
    """Test HTTP connectivity"""
    try:
        response = requests.get(url, timeout=5)
        return response.status_code, response.headers.get('content-type', 'unknown')
    except requests.exceptions.RequestException as e:
        return None, str(e)

def scan_network_for_camera():
    """Scan common IP addresses for camera server"""
    print("🔍 Scanning for camera server...")
    
    # Common IP patterns for local networks
    base_ips = [
        "192.168.1",
        "192.168.0", 
        "10.0.0",
        "172.16.0"
    ]
    
    common_host_numbers = [8, 100, 101, 102, 103, 104, 105, 200, 201, 202]
    port = 8080
    endpoint = "my_mac_camera"
    
    found_servers = []
    
    for base_ip in base_ips:
        for host_num in common_host_numbers:
            ip = f"{base_ip}.{host_num}"
            
            # Test socket connectivity first (faster)
            if test_ip_connectivity(ip, port):
                # Test HTTP connectivity
                test_url = f"http://{ip}:{port}/{endpoint}"
                status_code, content_type = test_http_connectivity(test_url)
                
                if status_code:
                    found_servers.append({
                        'ip': ip,
                        'url': test_url,
                        'status': status_code,
                        'content_type': content_type
                    })
                    print(f"✅ Found server at {ip}:{port} (Status: {status_code}, Type: {content_type})")
    
    return found_servers

def get_local_network_ranges():
    """Get local network IP ranges to scan"""
    try:
        # Get local IP address
        hostname = socket.gethostname()
        local_ip = socket.gethostbyname(hostname)
        
        # Create network object
        network = ipaddress.IPv4Network(f"{local_ip}/24", strict=False)
        base_network = str(network.network_address)[:-1]  # Remove last .0
        
        print(f"📍 Local IP: {local_ip}")
        print(f"📍 Network range: {network}")
        
        return [base_network]
    except Exception as e:
        print(f"⚠️  Could not determine local network: {e}")
        # Fallback to common ranges
        return ["192.168.1", "192.168.0", "10.0.0", "172.16.0"]

def ping_sweep(network_base, start_range=1, end_range=254):
    """Perform ping sweep to find active hosts"""
    print(f"🔍 Ping sweep: {network_base}.{start_range}-{end_range}")
    active_hosts = []
    
    def ping_host(host_num):
        ip = f"{network_base}.{host_num}"
        try:
            # Use platform-specific ping command
            if platform.system().lower() == "windows":
                result = subprocess.run(
                    ["ping", "-n", "1", "-w", "1000", ip],
                    capture_output=True,
                    text=True,
                    timeout=2
                )
            else:
                result = subprocess.run(
                    ["ping", "-c", "1", "-W", "1", ip],
                    capture_output=True,
                    text=True,
                    timeout=2
                )
            
            if result.returncode == 0:
                return ip
        except (subprocess.TimeoutExpired, Exception):
            pass
        return None
    
    # Use ThreadPoolExecutor for parallel ping
    with ThreadPoolExecutor(max_workers=50) as executor:
        futures = [executor.submit(ping_host, i) for i in range(start_range, end_range + 1)]
        
        for future in as_completed(futures):
            result = future.result()
            if result:
                active_hosts.append(result)
                print(f"   ✅ Host alive: {result}")
    
    return active_hosts

def scan_for_raspberry_pi_devices(active_hosts):
    """Scan active hosts for Raspberry Pi devices"""
    print("🔍 Scanning for Raspberry Pi devices...")
    raspberry_pi_hosts = []
    
    def check_raspberry_pi(ip):
        try:
            # Try to identify Raspberry Pi by checking common services/ports
            pi_indicators = []
            
            # Check SSH port (common on Pi)
            if test_ip_connectivity(ip, 22):
                pi_indicators.append("SSH")
            
            # Check for common Pi web services
            if test_ip_connectivity(ip, 80):
                pi_indicators.append("HTTP")
            
            # Check for camera server port
            if test_ip_connectivity(ip, 8080):
                pi_indicators.append("Camera")
            
            # Check for VNC (common on Pi)
            if test_ip_connectivity(ip, 5900):
                pi_indicators.append("VNC")
            
            # Try to get hostname (might reveal Pi)
            try:
                hostname = socket.gethostbyaddr(ip)[0]
                if any(pi_name in hostname.lower() for pi_name in ['raspberry', 'pi', 'rpi']):
                    pi_indicators.append(f"Hostname: {hostname}")
            except:
                pass
            
            if pi_indicators:
                return {
                    'ip': ip,
                    'indicators': pi_indicators,
                    'confidence': len(pi_indicators)
                }
        except Exception as e:
            pass
        return None
    
    # Scan hosts in parallel
    with ThreadPoolExecutor(max_workers=20) as executor:
        futures = [executor.submit(check_raspberry_pi, ip) for ip in active_hosts]
        
        for future in as_completed(futures):
            result = future.result()
            if result:
                raspberry_pi_hosts.append(result)
                indicators_str = ", ".join(result['indicators'])
                print(f"   🍓 Potential Raspberry Pi: {result['ip']} ({indicators_str})")
    
    return raspberry_pi_hosts

def scan_raspberry_pi_for_cameras(raspberry_pi_hosts):
    """Scan Raspberry Pi devices for camera servers"""
    print("🔍 Scanning Raspberry Pi devices for camera servers...")
    camera_servers = []
    
    # Common camera server ports and endpoints
    camera_ports = [8080, 8081, 8082, 8000, 8001, 5000, 5001, 80, 443]
    camera_endpoints = [
        "my_mac_camera",
        "video",
        "stream",
        "camera",
        "mjpeg",
        "feed",
        "cam",
        "webcam",
        "snapshot",
        "image"
    ]
    
    def check_camera_server(pi_device, port, endpoint):
        ip = pi_device['ip']
        test_url = f"http://{ip}:{port}/{endpoint}"
        
        try:
            status_code, content_type = test_http_connectivity(test_url)
            if status_code and status_code == 200:
                # Check if content type suggests video/image
                if any(media_type in content_type.lower() for media_type in 
                       ['image', 'video', 'stream', 'mjpeg', 'jpeg']):
                    return {
                        'ip': ip,
                        'port': port,
                        'endpoint': endpoint,
                        'url': test_url,
                        'status': status_code,
                        'content_type': content_type,
                        'pi_confidence': pi_device['confidence']
                    }
        except Exception:
            pass
        return None
    
    # Scan all combinations
    for pi_device in raspberry_pi_hosts:
        print(f"   🔍 Scanning {pi_device['ip']} for camera servers...")
        
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = []
            for port in camera_ports:
                for endpoint in camera_endpoints:
                    futures.append(executor.submit(check_camera_server, pi_device, port, endpoint))
            
            for future in as_completed(futures):
                result = future.result()
                if result:
                    camera_servers.append(result)
                    print(f"   📹 Found camera server: {result['url']} (Status: {result['status']}, Type: {result['content_type']})")
    
    return camera_servers

def auto_discover_camera_servers():
    """Automatically discover camera servers on the network"""
    print("🚀 Auto-discovering camera servers on the network...")
    print("=" * 60)
    
    # Step 1: Get network ranges
    network_ranges = get_local_network_ranges()
    
    # Step 2: Ping sweep to find active hosts
    all_active_hosts = []
    for network_base in network_ranges:
        active_hosts = ping_sweep(network_base)
        all_active_hosts.extend(active_hosts)
    
    if not all_active_hosts:
        print("❌ No active hosts found on the network")
        return []
    
    print(f"✅ Found {len(all_active_hosts)} active hosts")
    
    # Step 3: Identify potential Raspberry Pi devices
    raspberry_pi_hosts = scan_for_raspberry_pi_devices(all_active_hosts)
    
    if not raspberry_pi_hosts:
        print("⚠️  No Raspberry Pi devices detected, scanning all active hosts for cameras...")
        # If no Pi detected, scan all active hosts
        raspberry_pi_hosts = [{'ip': ip, 'indicators': [], 'confidence': 0} for ip in all_active_hosts]
    
    # Step 4: Scan Raspberry Pi devices for camera servers
    camera_servers = scan_raspberry_pi_for_cameras(raspberry_pi_hosts)
    
    return camera_servers

def main():
    print("🎥 Camera Server Diagnostic Tool")
    print("=" * 50)
    
    # Step 1: Auto-discover camera servers
    print("🚀 AUTO-DISCOVERY MODE")
    discovered_servers = auto_discover_camera_servers()
    
    if discovered_servers:
        print(f"\n🎉 AUTO-DISCOVERY FOUND {len(discovered_servers)} CAMERA SERVER(S):")
        for i, server in enumerate(discovered_servers, 1):
            confidence_level = "High" if server['pi_confidence'] >= 2 else "Medium" if server['pi_confidence'] >= 1 else "Low"
            print(f"   {i}. 📹 {server['url']}")
            print(f"      Status: {server['status']}, Type: {server['content_type']}")
            print(f"      Raspberry Pi Confidence: {confidence_level}")
            print()
        
        # Test the best candidate
        best_server = max(discovered_servers, key=lambda x: x['pi_confidence'])
        print(f"🎯 TESTING BEST CANDIDATE: {best_server['url']}")
        status_code, content_type = test_http_connectivity(best_server['url'])
        if status_code == 200:
            print("   ✅ Camera server is working perfectly!")
        else:
            print(f"   ⚠️  Camera server responded with status: {status_code}")
    else:
        print("\n⚠️  AUTO-DISCOVERY: No camera servers found")
    
    print("\n" + "=" * 50)
    print("🔍 MANUAL TESTING MODE")
    
    # Step 2: Test the default camera server
    default_ip = "192.168.1.8"
    default_port = 8080
    default_endpoint = "my_mac_camera"
    default_url = f"http://{default_ip}:{default_port}/{default_endpoint}"
    
    print(f"1. Testing default camera server: {default_url}")
    
    # Test socket connectivity
    print(f"   🔌 Testing socket connectivity to {default_ip}:{default_port}...")
    if test_ip_connectivity(default_ip, default_port):
        print("   ✅ Socket connection successful")
    else:
        print("   ❌ Socket connection failed")
    
    # Test HTTP connectivity
    print(f"   🌐 Testing HTTP connectivity to {default_url}...")
    status_code, content_type = test_http_connectivity(default_url)
    if status_code:
        print(f"   ✅ HTTP connection successful (Status: {status_code}, Type: {content_type})")
    else:
        print(f"   ❌ HTTP connection failed: {content_type}")
    
    print("\n2. Scanning common IP addresses for camera servers...")
    found_servers = scan_network_for_camera()
    
    if found_servers:
        print(f"\n✅ Found {len(found_servers)} camera server(s) via manual scan:")
        for server in found_servers:
            print(f"   📍 {server['url']} (Status: {server['status']}, Type: {server['content_type']})")
    else:
        print("\n❌ No camera servers found via manual scan")
    
    # Combine results
    total_servers = len(discovered_servers) + len(found_servers)
    
    print(f"\n📊 SUMMARY:")
    print(f"   Auto-discovered servers: {len(discovered_servers)}")
    print(f"   Manually found servers: {len(found_servers)}")
    print(f"   Total unique servers: {total_servers}")
    
    if total_servers > 0:
        print(f"\n🎯 RECOMMENDATIONS:")
        if discovered_servers:
            best_server = max(discovered_servers, key=lambda x: x['pi_confidence'])
            print(f"   🥇 Best camera server: {best_server['url']}")
            print(f"   📱 Update your Flutter app to use this URL")
            print(f"   � IP Address: {best_server['ip']}")
            print(f"   🔧 Port: {best_server['port']}")
            print(f"   🔧 Endpoint: {best_server['endpoint']}")
        else:
            print(f"   📍 Use one of the manually found servers")
    
    print("\n3. Troubleshooting Tips:")
    print("   📋 Make sure the camera server is running:")
    print("       python server.py")
    print("   📋 Check your network configuration:")
    print("       - Ensure both devices are on the same network")
    print("       - Check firewall settings")
    print("       - Verify IP address with: ipconfig (Windows) or ifconfig (Mac/Linux)")
    print("   📋 Test from browser:")
    print(f"       Open: {default_url}")
    
    return total_servers > 0

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n⚠️  Scan interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)
