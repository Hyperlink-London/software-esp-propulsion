#!/bin/bash

# Board and paths
FQBN="esp32:esp32:esp32doit-devkit-v1"
SKETCH_DIR="./propulsion-firmware"
LIBS="./interfaces,./sensors,./comms"
BUILD_OUT="./build"

# Flags
UPLOAD=true
UPLOAD_ONLY=false
COMPILE_ONLY=false

# Parse arguments
for arg in "$@"; do
  case $arg in
    --no-upload)
      UPLOAD=false
      echo "Upload disabled (--no-upload)"
      ;;
    --upload-only)
      UPLOAD_ONLY=true
      echo "Upload-only mode enabled (--upload-only)"
      ;;
    --compile-only)
      COMPILE_ONLY=true
      UPLOAD=false
      echo "Compile-only mode enabled (--compile-only)"
      ;;
  esac
done

# Check for invalid flag combinations
if [ "$UPLOAD_ONLY" = true ] && [ "$COMPILE_ONLY" = true ]; then
  echo "Error: --upload-only and --compile-only cannot be used together."
  exit 1
fi

# Spinner and timer function
run_with_spinner() {
  local pid=$1
  local label=$2
  local spinner="/|\\-/|\\-"
  local counter=0
  local start_time=$(date +%s)

  while kill -0 "$pid" 2>/dev/null; do
    now=$(date +%s)
    elapsed=$((now - start_time))
    printf "\r[%3ds] %s %s" "$elapsed" "$label" "${spinner:counter++%${#spinner}:1}"
    sleep 0.1
  done

  wait "$pid"
  return $?
}

# Cleanup on interrupt
TMP_LOG=""
cleanup() {
  echo
  echo "Build interrupted. Cleaning up..."
  [ -f "$TMP_LOG" ] && rm -f "$TMP_LOG"
  [ -d "$BUILD_OUT" ] && rm -rf "$BUILD_OUT"
  exit 1
}
trap cleanup INT TERM

# ---- Compilation Phase ----
if [ "$UPLOAD_ONLY" = false ]; then
  # Install required libraries
  echo "Checking for required libraries..."
  if ! arduino-cli lib list | grep -q "ArduinoJson"; then
    echo "Installing ArduinoJson library..."
    arduino-cli lib install "ArduinoJson"
  else
    echo "ArduinoJson library already installed."
  fi

  # Clean build directory
  if [ -d "$BUILD_OUT" ]; then
    echo "Cleaning existing build directory..."
    rm -rf "$BUILD_OUT"
  fi
  mkdir -p "$BUILD_OUT"

  echo -n "Compiling firmware:  "
  TMP_LOG=$(mktemp)

  arduino-cli compile \
    --fqbn "$FQBN" \
    --build-property "build.extra_flags=-I$SKETCH_DIR -Wall -Wextra -Wpedantic" \
    "$SKETCH_DIR" \
    --libraries $LIBS \
    --output-dir "$BUILD_OUT" > "$TMP_LOG" 2>&1 &

  COMP_PID=$!

  run_with_spinner $COMP_PID "Compiling firmware:"
  COMP_STATUS=$?

  # Preserve spinner output and move down
  echo
  echo

  cat "$TMP_LOG"
  rm -f "$TMP_LOG"
  trap - INT TERM

  if [ $COMP_STATUS -ne 0 ]; then
    echo "Build failed."
    exit 1
  fi

  echo "Build successful. Output located in: $BUILD_OUT"
  echo
else
  # Validate build output exists
  if [ ! -d "$BUILD_OUT" ] || [ -z "$(ls -A "$BUILD_OUT")" ]; then
    echo "Error: --upload-only requested but build directory is missing or empty."
    exit 1
  fi
fi

# ---- Upload Phase ----
if [ "$UPLOAD" = true ] && [ "$COMPILE_ONLY" = false ]; then
  echo "Available serial ports:"
  arduino-cli board list

  DEFAULT_PORT="/dev/cu.usbserial-0001"
  echo
  read -p "Enter the port to upload to [default: $DEFAULT_PORT]: " PORT

  PORT="${PORT:-$DEFAULT_PORT}"

  echo -n "Uploading firmware to $PORT: "
  counter=0
  start_time=$(date +%s)

  arduino-cli upload \
    -p "$PORT" \
    --fqbn "$FQBN" \
    --input-dir "$BUILD_OUT" \
    "$SKETCH_DIR" &
  UPLOAD_PID=$!

  while kill -0 "$UPLOAD_PID" 2>/dev/null; do
    now=$(date +%s)
    elapsed=$((now - start_time))
    printf "\r[%3ds] Uploading firmware to $PORT:  %s" "$elapsed" "${spinner:counter++%${#spinner}:1}"
    sleep 0.1
  done

  wait "$UPLOAD_PID"
  UPLOAD_STATUS=$?
  echo
  echo

  if [ $UPLOAD_STATUS -eq 0 ]; then
    echo "[${elapsed}s] Upload successful on port: $PORT"

    read -p "Open serial monitor now? (y/N): " RESP
    if [[ "$RESP" =~ ^[Yy]$ ]]; then
      echo "Opening serial monitor on $PORT (baud: 9600)..."
      arduino-cli monitor -p "$PORT"
    fi
  else
    echo "[${elapsed}s] Upload failed on port: $PORT"
  fi
fi
