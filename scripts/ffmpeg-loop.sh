#!/bin/sh
# Endlessly loops test.mp4 into MediaMTX as an RTSP stream.
sleep 3
while true; do
  ffmpeg -re -stream_loop -1 -i /videos/test.mp4 \
    -c:v libx264 -preset ultrafast -tune zerolatency \
    -g 30 -keyint_min 30 -sc_threshold 0 \
    -b:v 800k -maxrate 800k -bufsize 1600k \
    -an \
    -f rtsp -rtsp_transport tcp \
    rtsp://media-server:8554/test-video || true
  echo "FFmpeg exited, restarting in 2s..."
  sleep 2
done
