# You'll need to install: pip install opencv-python mjpeg-streamer
import cv2
import time
from mjpeg_streamer import MjpegServer, Stream

print("Initializing camera...")
cap = cv2.VideoCapture(0) # 0 is usually the default webcam

if not cap.isOpened():
    print("Error: Could not open camera")
    exit(1)

print("Camera opened successfully")
stream = Stream("my_mac_camera", size=(640, 480), quality=70, fps=20)
server = MjpegServer("0.0.0.0", 8080) # Listen on all interfaces, port 8080
server.add_stream(stream)
server.start()

print("MJPEG stream available at http://YOUR_MAC_IP:8080/my_mac_camera")
print("Camera streaming started...")

frame_count = 0
try:
    while True:
        ret, frame = cap.read()
        if not ret:
            print("Failed to grab frame")
            time.sleep(0.1)
            continue
        
        stream.set_frame(frame)
        frame_count += 1
        
        if frame_count % 100 == 0:  # Print every 100 frames
            print(f"Streamed {frame_count} frames")
        
        if cv2.waitKey(1) == ord('q'): # Press 'q' to quit
            break
            
except KeyboardInterrupt:
    print("\nShutting down...")
except Exception as e:
    print(f"Error: {e}")
finally:
    server.stop()
    cap.release()
    cv2.destroyAllWindows()
    print("Cleanup completed")