#!/bin/bash

CONFIG_FILE="propulsion-firmware/config-ci.h"
SENSORS_DIR="sensors/src"

missing_defines=()

# Function to convert CamelCase or camelCase to SCREAMING_SNAKE_CASE
to_macro_case() {
  echo "$1" |
    sed -E 's/([a-z])([A-Z])/\1_\2/g' |  # Insert _ between camelCase
    tr '[:lower:]' '[:upper:]'          # Convert to uppercase
}

for file in "$SENSORS_DIR"/*.cpp; do
    base=$(basename "$file" .cpp)

    [[ "$base" == "SensorManager" ]] && continue

    macro_base=$(to_macro_case "$base")
    macro="USE_${macro_base}"

    if ! grep -q "#define $macro" "$CONFIG_FILE"; then
        missing_defines+=("$macro")
    fi
done

if [ ${#missing_defines[@]} -ne 0 ]; then
    echo "Missing sensor defines in $CONFIG_FILE:"
    for macro in "${missing_defines[@]}"; do
        echo "  - $macro"
    done
    exit 1
else
    echo "All sensors are registered in $CONFIG_FILE"
fi
