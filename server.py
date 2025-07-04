# You'll need to install: pip install opencv-python mjpeg-streamer
import cv2
from mjpeg_streamer import MjpegServer, Stream

cap = cv2.VideoCapture(0) # 0 is usually the default webcam
stream = Stream("my_mac_camera", size=(640, 480), quality=70, fps=20)
server = MjpegServer("0.0.0.0", 8080) # Listen on all interfaces, port 8080
server.add_stream(stream)
server.start()

print("MJPEG stream available at http://YOUR_MAC_IP:8080/my_mac_camera")

while True:
    ret, frame = cap.read()
    if not ret:
        print("Failed to grab frame")
        break
    stream.set_frame(frame)
    if cv2.waitKey(1) == ord('q'): # Press 'q' to quit
        break

server.stop()
cap.release()
cv2.destroyAllWindows()