#!/bin/bash

# Board and paths
FQBN="esp32:esp32:esp32doit-devkit-v1"
SKETCH_DIR="./propulsion-firmware"
LIBS="./interfaces,./sensors,./comms"
BUILD_OUT="./build"

# Flags
UPLOAD=true
UPLOAD_ONLY=false

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
  esac
done

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
  # Clean build directory
  if [ -d "$BUILD_OUT" ]; then
    echo "Cleaning existing build directory..."
    rm -rf "$BUILD_OUT"
  fi
  mkdir -p "$BUILD_OUT"

  echo -n "Compiling firmware:  "
  TMP_LOG=$(mktemp)

  # --build-property adds the main sketch directory to include path so config.h is visible in submodules (this was a pain to figure out...)
  arduino-cli compile \
    --fqbn "$FQBN" \
    --build-property "build.extra_flags=-I$SKETCH_DIR" \
    "$SKETCH_DIR" \
    --libraries $LIBS \
    --output-dir "$BUILD_OUT" > "$TMP_LOG" 2>&1 &

  COMP_PID=$!

  run_with_spinner $COMP_PID "Compiling firmware:"
  COMP_STATUS=$?

  # Preserve spinner output and move down
  echo
  echo

  # Print logs and cleanup
  cat "$TMP_LOG"
  rm -f "$TMP_LOG"
  trap - INT TERM  # Disable trap now that we're done cleaning

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
if [ "$UPLOAD" = true ]; then
  echo "Available serial ports:"
  arduino-cli board list

  DEFAULT_PORT="/dev/cu.usbserial-0001"
  echo
  read -p "Enter the port to upload to [default: $DEFAULT_PORT]: " PORT

  # Use default if input is empty
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
  else
    echo "[${elapsed}s] Upload failed on port: $PORT"
  fi
fi
