# ESP32 Propulsion Firmware

This repository contains the main firmware for the ESP32-based propulsion control system. It integrates modular sensor management and communication logic using well-separated Arduino library-style submodules. The firmware is designed for clarity, maintainability, and extensibility in embedded systems development.

## Repository Structure

This repository consists of the following submodules:

- **sensors/**: Handles sensor management, abstraction, and polling logic. Contains `SensorManager` and sensor implementations.
- **comms/**: Contains communication-related classes for both input and output (e.g., via serial, BLE, or network). Includes `CommsIn` for command reception and `CommsOut` for data transmission.
- **interfaces/**: A lightweight interface module that provides shared abstract classes, such as `CommsOutInterface` and `CommsInInterface`, used to decouple `sensors` from `comms`.

The firmware source code is located in the `propulsion-firmware/` directory.

```
software-esp-propulsion/
├── propulsion-firmware/         # Main Arduino sketch
│   ├── propulsion-firmware.ino  # Main sketch file
│   ├── commands.h               # Command function declarations
│   ├── commands.cpp             # Command function implementations
│   ├── config.h                 # Sensor configuration (user-editable)
│   ├── config-ci.h              # CI build configuration
│   └── firmware.properties      # Firmware dependency declarations
├── sensors/                     # Submodule: sensor logic
│   ├── src/
│   │   ├── SensorManager.h/cpp  # Main sensor management class
│   │   └── [sensor implementations]
│   └── library.properties       # Library metadata and dependencies
├── comms/                       # Submodule: communication logic
│   ├── src/
│   │   ├── CommsIn.h/cpp        # Command reception and execution
│   │   └── CommsOut.h/cpp       # Data transmission and queuing
│   └── library.properties       # Library metadata and dependencies
├── interfaces/                  # Submodule: shared interfaces
│   ├── src/
│   │   ├── CommsOutInterface.h  # Abstract interface for output
│   │   ├── CommsInInterface.h   # Abstract interface for input
│   │   ├── SensorInterface.h    # Abstract interface for sensors
│   │   └── SerialAliases.h      # Serial port aliases
│   └── library.properties       # Library metadata
├── docs/                        # Project documentation
│   ├── WORKFLOW.md
│   ├── DECISION-MAKING.md
│   └── ARDUINO-LIBRARIES.md
├── scripts/                     # Utility scripts
│   └── check-config-sensors.sh  # Validates sensor configuration
├── build/                       # Build output directory (generated)
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
- Check and install ESP32 core if missing
- Check and install all required library dependencies (from `library.properties` and `firmware.properties` files)
- Clean the build directory
- Compile the firmware using Arduino CLI
- Optionally upload to a connected ESP32 board (unless `--no-upload` is specified)

### Build Script Options

- `./build.sh` - Compile and upload (prompts for serial port)
- `./build.sh --no-upload` - Compile only, do not upload
- `./build.sh --compile-only` - Compile only (same as --no-upload)
- `./build.sh --upload-only` - Upload only (requires existing build)

### Flashing Notes

The script will prompt you to select a serial port for uploading. By default, it suggests `/dev/cu.usbserial-0001` (adjust for your system). After successful upload, you can optionally open the serial monitor.

## Design Overview

The firmware is built around modular components with strict separation of concerns:

- **SensorManager**: Resides in the `sensors` module. Responsible for managing active sensors, polling data, and forwarding values.
- **CommsOut**: Resides in the `comms` module. Implements a `CommsOutInterface` used by `SensorManager` to send sensor data. Also handles transmission of sensor data and ACK messages via serial communication.
- **CommsIn**: Resides in the `comms` module. Handles incoming commands from the OBC, validates ESP ID, executes commands through a dynamic command map, and sends ACK responses.
- **CommsOutInterface**: Defined in the `interfaces` module to decouple `sensors` from `comms`.
- **CommsInInterface**: Defined in the `interfaces` module to provide a standard interface for command reception.

This modular design enables flexible integration, testing, and future support for multiple communication or sensor configurations.

## Core Architecture

The ESP32 dual-core architecture is utilised to separate sensor polling from communication handling:

### Core 0: Sensor Polling
- **Task**: `PollSensors` (SensorTask)
- **Classes Used**:
  - `SensorManager` (from `sensors` module): Manages and polls all active sensors
  - `CommsOut` (from `comms` module): Queues sensor data for transmission
- **Responsibilities**:
  - Polls all active sensors every 1000ms via `SensorManager::pollSensors()`
  - Collects sensor data and forwards to `CommsOut::send()`
  - Sensor data is queued for transmission to avoid blocking sensor polling
- **Communication**: Sensor data is queued using FreeRTOS queue, not sent directly

### Core 1: Communication Handling
- **Task**: `HandleCommunication` (CommTask)
- **Classes Used**:
  - `CommsIn` (from `comms` module): Handles incoming commands from OBC
  - `CommsOut` (from `comms` module): Transmits sensor data and ACK messages
- **Responsibilities**:
  - Receives commands from OBC via `CommsIn::receive()` (every 5ms)
  - Validates ESP ID and executes commands through the command map
  - Sends ACK messages back to OBC via `CommsOut::sendAck()`
  - Drains the sensor data queue and transmits via `CommsOut::drainQueue()` (every 5ms)
  - Monitors communication staleness via `CommsIn::isStale()`
- **Communication**: All serial communication (Serial_1) is handled on this core to prevent conflicts

### Inter-Core Communication

**FreeRTOS Queue**:
- Sensor data from Core 0 is queued using `xQueueSend()` when `CommsOut::send()` is called
- Core 1 drains the queue using `CommsOut::drainQueue()` and transmits data via Serial_1
- Queue size: 32 messages
- If `CommsOut::send()` is called from Core 1, it bypasses the queue and sends directly (useful for ACK messages)

**Serial Communication**:
- **Serial_1** (9600 baud): Used for OBC communication (commands and sensor data)
- **Serial_0** (115200 baud): Used for debugging/development

This architecture ensures that sensor polling remains non-blocking and communication handling is responsive, preventing sensor data loss while maintaining real-time command processing.

## Command System

The firmware implements a JSON-based command system for receiving instructions from the OBC:

**Command Format**:
```json
{"espId": "esp-propulsion", "command": "turn_on_brake"}
```

**Response Format** (ACK):
```json
{"espId": "esp-propulsion", "ack": true, "command": "turn_on_brake"}
```

- Commands are defined in `propulsion-firmware/commands.h` and implemented in `commands.cpp`
- All command functions return `bool` (true = success, false = failure)
- ESP ID validation ensures commands are only executed for the correct device
- ACK messages are automatically sent back to the OBC after command execution

To add new commands:
1. Declare the function in `commands.h` (return type: `bool`)
2. Implement the function in `commands.cpp`
3. Add an entry to the `commands` array in `propulsion-firmware.ino`

## Development Notes

- Submodules are structured as Arduino-compatible libraries with `library.properties` files.
- All source files follow Arduino CLI's expected folder layout.
- Interface-based abstraction is used to maximise testability and portability.
- Dependencies are automatically managed via `library.properties` and `firmware.properties` files.
- Sensor configuration is managed through `propulsion-firmware/config.h` (enable/disable sensors via `#define` flags).

## Documentation

For more information on project structure, usage, and contribution workflows, refer to the following documentation:

- [Development Workflow](docs/WORKFLOW.md): How to work with the repository and its submodules.
- [Decision-Making Record](docs/DECISION-MAKING.md): Detailed reasoning and history behind key architectural decisions.
- [Arduino Libraries Guide](docs/ARDUINO-LIBRARIES.md): Explains how Arduino libraries work, how they are structured, and best practices.
