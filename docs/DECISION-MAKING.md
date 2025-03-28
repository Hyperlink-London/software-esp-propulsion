# Decision-Making Record

This document outlines the architectural and design decisions made during the development of the ESP32 Propulsion Firmware project. It serves to explain the rationale behind structural choices, trade-offs considered, and technical conclusions drawn throughout the design process.

## Overview

The system is designed to control and monitor a propulsion environment on an ESP32 microcontroller. To support scalability, testability, and modular development, the firmware is built around a decoupled architecture using Arduino-compatible libraries organised as submodules.

---

## Initial Project Goals

- Design a flexible system where different sensors can be enabled or disabled at runtime.
- Build a general-purpose `SensorManager` capable of interacting with any number of sensors in a unified way.
- Route sensor data to an outbound communication mechanism (`CommsOut`), which may vary in implementation (e.g., Serial, BLE, etc.).
- Keep all modules reusable and independently maintainable.

---

## Key Architectural Decisions

### 1. Modular Submodules for Reuse and Maintainability

**Decision**: Break the firmware system into multiple Git submodules:
- `sensors`: Handles sensor-specific logic and the `SensorManager` class.
- `comms`: Handles communication logic such as `CommsOut`.
- `interfaces`: Contains abstract interface definitions used to decouple modules.
- `propulsion-firmware`: The main firmware logic that integrates all modules.

**Rationale**:
- Allows each module to be developed and tested in isolation.
- Promotes reusability across other firmware projects.
- Enables clear separation of responsibilities and ownership.

---

### 2. Avoiding Direct Dependencies Between Submodules

**Problem Identified**: Initially, `SensorManager` in the `sensors` module needed to call `CommsOut::send(...)`, but `CommsOut` was implemented in a different submodule.

**Rejected Solution**: Directly including `CommsOut.h` in the `sensors` submodule.
- Creates tight coupling.
- Breaks reusability of `sensors` without `comms`.

**Accepted Solution**: Introduce a shared interface (`CommsOutInterface`) placed in a neutral `interfaces` submodule.

**Outcome**:
- `SensorManager` depends only on `CommsOutInterface`.
- `CommsOut` in the `comms` submodule implements `CommsOutInterface`.
- `propulsion-firmware` passes a concrete `CommsOut` object into `SensorManager` at runtime.

---

### 3. Use of Interface Injection (Dependency Inversion)

**Decision**: The `SensorManager` constructor accepts a pointer to a `CommsOutInterface`.

**Rationale**:
- Follows the Dependency Inversion Principle (DIP) from SOLID design.
- Enables testing `SensorManager` with mock implementations.
- Decouples the manager from concrete comms implementations.

**Example**:
```cpp
SensorManager::SensorManager(CommsOutInterface* commsOut)
    : comms(commsOut) { ... }
```

---

### 4. All Sensors Implement a Common Interface

**Decision**: Introduce a `SensorInterface` class that all sensors must implement, with required methods `setup()`, `update()`, and `getVal()`.

**Rationale**:
- Allows uniform handling of sensors by `SensorManager`.
- Encourages consistent interface across sensor implementations.
- Enables optional sensors to be toggled via `#define` macros without changing the `SensorManager` logic.

---

### 5. Build System Using Arduino CLI

**Decision**: Use `arduino-cli` instead of PlatformIO or Arduino IDE.

**Rationale**:
- More easily integrated into automated CI/CD pipelines.
- Better suited to Linux/macOS workflows.
- Scripting flexibility with shell.

**Build Script Features**:
- Auto-clean before every build.
- Optional `--no-upload` flag to disable flashing.
- Auto-detection of connected ESP32 board for upload.
- Dynamic linking of submodule libraries via `--libraries` flag.

---

### 6. Interface Location and Ownership

**Considered**: Placing `CommsOutInterface` inside `sensors`.

**Rejected**: This would force `comms` to depend on `sensors`, violating layering.

**Final Choice**: Move `CommsOutInterface` into an `interfaces` submodule.

**Rationale**:
- Keeps interfaces independent and shared.
- Avoids circular dependency chains.
- Encourages separation of contract vs implementation.

---

### 7. Dynamic Sensor Polling Strategy

**Decision**: `SensorManager` polls all connected sensors and transmits values either when:
- The value has changed
- A configured interval (`MAX_SILENT_PERIOD_MS`) has passed

**Rationale**:
- Reduces unnecessary data transmission.
- Ensures periodic updates even for stable sensors.
- Keeps communication predictable and bounded.

---

### 8. Project Naming and Structure

**Decision**: Name the firmware directory `propulsion-firmware` and use `.ino` files named `propulsion-firmware.ino`.

**Rationale**:
- Follows Arduino CLI’s requirement: `.ino` file name must match the folder name.
- Avoids compiler errors related to sketch structure.

---

## Summary of Rejected Alternatives

| Alternative                         | Rejected Because |
|-------------------------------------|------------------|
| Direct `#include` of `CommsOut` in `SensorManager` | Creates tight coupling |
| Hosting `CommsOutInterface` in `sensors`           | Introduces circular dependencies |
| Using a monolithic repo              | Prevents reuse and separation of concerns |
| PlatformIO                          | Less flexible in Unix automation scripts |
| Async sensor callbacks              | Unnecessary complexity for polling-only system |

---

## Future Considerations

- Introduce `CommsInInterface` to handle inbound commands and control.
- Add interface versioning or compatibility checking.
- Integrate hardware abstraction layer for GPIO and pin definitions.
- Move toward interface-driven simulation and testing with mock drivers.

