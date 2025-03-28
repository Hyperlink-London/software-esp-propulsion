#!/bin/bash

# Board and paths
FQBN="esp32:esp32:esp32"
SKETCH_DIR="./propulsion-firmware"
LIBS="./sensors,./comms"
BUILD_OUT="./build"

# Flags
UPLOAD=true

# Parse flags
for arg in "$@"; do
  case $arg in
    --no-upload)
      UPLOAD=false
      echo "Upload disabled (--no-upload)"
      ;;
  esac
done

# 🧹 Clean build directory
if [ -d "$BUILD_OUT" ]; then
  echo "Cleaning existing build directory..."
  rm -rf "$BUILD_OUT"
fi
mkdir -p "$BUILD_OUT"

# Compile the firmware
echo "Compiling firmware..."
arduino-cli compile \
  --fqbn "$FQBN" \
  "$SKETCH_DIR" \
  --libraries $LIBS \
  --output-dir "$BUILD_OUT"

if [ $? -ne 0 ]; then
  echo "Build failed."
  exit 1
fi

echo "Build successful. Output in: $BUILD_OUT"

# Upload firmware to ESP (if enabled)
if [ "$UPLOAD" = true ]; then
  PORT=$(arduino-cli board list | grep "esp32" | awk '{print $1}')

  if [ -z "$PORT" ]; then
    echo "No ESP32 board detected. Skipping upload."
  else
    echo "ESP32 detected at $PORT"
    echo "Uploading firmware..."
    arduino-cli upload \
      -p "$PORT" \
      --fqbn "$FQBN" \
      --input-dir "$BUILD_OUT" \
      "$SKETCH_DIR"

    if [ $? -eq 0 ]; then
      echo "Upload successful on port: $PORT"
    else
      echo "Upload failed on port: $PORT"
    fi
  fi
fi
