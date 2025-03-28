#!/bin/bash

CONFIG_FILE="propulsion-firmware/config-ci.h"
SENSORS_DIR="sensors/src"

missing_defines=()

for file in "$SENSORS_DIR"/*.cpp; do
    base=$(basename "$file" .cpp)

    # Skip SensorManager or other non-sensor cpp files
    [[ "$base" == "SensorManager" ]] && continue

    macro="USE_${base^^}"  # Convert to uppercase

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
