# ESP32 Propulsion Firmware

This repository contains the main firmware for the ESP32-based propulsion control system. It integrates modular sensor management and communication logic using well-separated Arduino library-style submodules. The firmware is designed for clarity, maintainability, and extensibility in embedded systems development.

## Repository Structure

This repository consists of the following submodules:

- **sensors/**: Handles sensor management, abstraction, and polling logic.
- **comms/**: Contains communication-related classes for output (e.g., via serial, BLE, or network).
- **interfaces/**: A lightweight interface module that provides shared abstract classes, such as `CommsOutInterface`, used to decouple `sensors` from `comms`.

The firmware source code is located in the `propulsion-firmware/` directory.

```
software-esp-propulsion/
├── propulsion-firmware/         # Main Arduino sketch
│   └── propulsion-firmware.ino
├── sensors/                     # Submodule: sensor logic
│   └── src/
├── comms/                       # Submodule: communication logic
│   └── src/
├── interfaces/                  # Submodule: shared interfaces
│   └── src/
├── docs/                        # Project documentation
│   ├── WORKFLOW.md
│   ├── DECISION-MAKING.md
│   └── ARDUINO-LIBRARIES.md
├── build.sh                     # Build and optional upload script
└── README.md
```

## Getting Started

### Prerequisites

- [Arduino CLI](https://arduino.github.io/arduino-cli/latest/installation/) version 0.34.0 or later
- ESP32 core installed via:
  ```bash
  arduino-cli core install esp32:esp32
  ```
- This repository cloned **recursively** to include all submodules:
  ```bash
  git clone --recursive-submodules <repo-url / repo-ssh>
  ```

  # TODO: explain pulling workflow for recursive submodules

### Build Instructions

To compile the firmware:

```bash
./build.sh
```

To compile without uploading:

```bash
./build.sh --no-upload
```

The script will:
- Clean the build directory
- Compile the firmware using Arduino CLI
- Automatically detect a connected ESP32 board and upload (unless `--no-upload` is specified)

### Flashing Notes

By default, the script will flash to the first connected device identified as `esp32`. If multiple boards are connected or detection fails, consider extending the script with manual port selection.

## Design Overview

The firmware is built around modular components with strict separation of concerns:

- **SensorManager**: Resides in the `sensors` module. Responsible for managing active sensors, polling data, and forwarding values.
- **CommsOut**: Resides in the `comms` module. Implements a `CommsOutInterface` used by `SensorManager` to send sensor data.
- **CommsOutInterface**: Defined in the `interfaces` module to decouple `sensors` from `comms`.

This modular design enables flexible integration, testing, and future support for multiple communication or sensor configurations.

## Development Notes

- Submodules are structured as Arduino-compatible libraries with `library.properties` files.
- All source files follow Arduino CLI's expected folder layout.
- Interface-based abstraction is used to maximise testability and portability.

## Documentation

For more information on project structure, usage, and contribution workflows, refer to the following documentation:

- [Development Workflow](docs/WORKFLOW.md): How to work with the repository and its submodules.
- [Decision-Making Record](docs/DECISION-MAKING.md): Detailed reasoning and history behind key architectural decisions.
- [Arduino Libraries Guide](docs/ARDUINO-LIBRARIES.md): Explains how Arduino libraries work, how they are structured, and best practices.
