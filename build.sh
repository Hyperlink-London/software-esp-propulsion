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

# Function to check ESP32 core is installed
check_esp32_core() {
  echo "Checking for ESP32 core..."
  if arduino-cli core list | grep -q "esp32:esp32"; then
    echo "✓ ESP32 core is installed."
    return 0
  else
    echo "✗ ESP32 core is not installed."
    echo "Installing ESP32 core..."
    if arduino-cli core update-index && arduino-cli core install esp32:esp32; then
      echo "✓ ESP32 core installed successfully."
      return 0
    else
      echo "✗ Failed to install ESP32 core."
      return 1
    fi
  fi
}

# Function to check and install dependencies
check_and_install_dependencies() {
  echo "Checking for required libraries..."
  
  # Local libraries that don't need to be installed (they're in the repo)
  local LOCAL_LIBS=("Interfaces")
  
  # Cores that don't need to be installed as libraries
  local CORES=("Arduino")
  
  # Collect all dependencies from library.properties and firmware.properties files
  local ALL_DEPS=()
  
  # Find all library.properties and firmware.properties files and extract dependencies
  while IFS= read -r props_file; do
    if [ -f "$props_file" ]; then
      # Extract depends line and split by comma
      local deps_line=$(grep "^depends=" "$props_file" | cut -d'=' -f2)
      if [ -n "$deps_line" ]; then
        # Split comma-separated dependencies
        IFS=',' read -ra DEPS <<< "$deps_line"
        for dep in "${DEPS[@]}"; do
          # Trim whitespace
          dep=$(echo "$dep" | xargs)
          # Skip if empty, local library, or core
          if [ -n "$dep" ]; then
            local skip=false
            for local_lib in "${LOCAL_LIBS[@]}"; do
              if [ "$dep" = "$local_lib" ]; then
                skip=true
                break
              fi
            done
            for core in "${CORES[@]}"; do
              if [ "$dep" = "$core" ]; then
                skip=true
                break
              fi
            done
            if [ "$skip" = false ]; then
              ALL_DEPS+=("$dep")
            fi
          fi
        done
      fi
    fi
  done < <(find . -name "library.properties" -o -name "firmware.properties" -type f)
  
  # Remove duplicates
  local UNIQUE_DEPS=($(printf "%s\n" "${ALL_DEPS[@]}" | sort -u))
  
  if [ ${#UNIQUE_DEPS[@]} -eq 0 ]; then
    echo "No external dependencies found."
    return 0
  fi
  
  # Check and install each dependency
  for lib in "${UNIQUE_DEPS[@]}"; do
    if arduino-cli lib list | grep -q "^$lib "; then
      echo "✓ $lib library already installed."
    else
      echo "Installing $lib library..."
      if arduino-cli lib install "$lib"; then
        echo "✓ $lib library installed successfully."
      else
        echo "✗ Failed to install $lib library."
        return 1
      fi
    fi
  done
  
  echo "All dependencies checked."
  echo
}

# ---- Compilation Phase ----
if [ "$UPLOAD_ONLY" = false ]; then
  # Check ESP32 core is installed (required for FreeRTOS headers)
  check_esp32_core || exit 1
  echo
  
  # Check and install all dependencies from library.properties files
  check_and_install_dependencies || exit 1

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
