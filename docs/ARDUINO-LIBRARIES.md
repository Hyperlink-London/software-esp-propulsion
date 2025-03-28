# Understanding Arduino Libraries

This document provides an in-depth explanation of how Arduino libraries are structured and how they work, intended for contributors who may be new to the Arduino ecosystem. It covers:

- What Arduino libraries are
- How they are structured
- How to use them in projects
- How Arduino CLI resolves and compiles them
- Best practices for writing modular, reusable Arduino libraries

---

## What Is an Arduino Library?

An Arduino library is a self-contained collection of code that provides reusable functionality for Arduino sketches. Libraries help developers modularise and encapsulate specific functionality, such as sensor drivers, communication protocols, or hardware abstractions.

Arduino libraries are used to avoid rewriting code and to make projects easier to manage and scale.

---

## Structure of an Arduino Library

A standard Arduino library follows a defined folder and file structure. At a minimum, it includes:

```
YourLibrary/
├── src/
│   ├── YourLibrary.h
│   └── YourLibrary.cpp
├── library.properties
└── README.md (optional)
```

### Explanation of Components

| File/Folder           | Description |
|-----------------------|-------------|
| `src/`                | Required. Contains all source (`.cpp`) and header (`.h`) files for the library. |
| `YourLibrary.h`       | The main header file. Defines the public interface of the library (classes, methods, etc.). |
| `YourLibrary.cpp`     | The implementation file. Contains the logic for the classes declared in the header. |
| `library.properties`  | Required. A metadata file that tells Arduino CLI or the Arduino IDE about your library (name, version, description, author, etc.). |
| `README.md`           | Optional. Describes what the library does, how to use it, and any examples. |

---

## Example: Minimal Temperature Sensor Library

```
TemperatureSensor/
├── src/
│   ├── TemperatureSensor.h
│   └── TemperatureSensor.cpp
├── library.properties
```

**TemperatureSensor.h**
```cpp
#ifndef TEMPERATURE_SENSOR_H
#define TEMPERATURE_SENSOR_H

class TemperatureSensor {
public:
    void begin();
    float readCelsius();
};

#endif
```

**TemperatureSensor.cpp**
```cpp
#include "TemperatureSensor.h"

void TemperatureSensor::begin() {
    // Sensor init code
}

float TemperatureSensor::readCelsius() {
    return 25.0; // Dummy value
}
```

**library.properties**
```properties
name=TemperatureSensor
version=1.0.0
author=John Doe
maintainer=John Doe
sentence=A simple temperature sensor library.
paragraph=This library reads from a generic temperature sensor.
category=Sensors
architecture=*
```

---

## Using Arduino Libraries in Projects

There are two ways to use a library in an Arduino project:

### 1. **System-Wide Installation** (not needed but good to know)

Copy the library to your Arduino libraries folder:

- macOS/Linux: `~/Documents/Arduino/libraries/`
- Windows: `Documents\Arduino\libraries\`

Then, in your sketch:

```cpp
#include <TemperatureSensor.h>
```

Arduino CLI or the IDE will automatically detect the library.

---

### 2. **Local Use in Modular Projects (Recommended for Advanced Use)** (not needed as the build.sh takes care of this)

For modular, multi-library projects (like this one), you can:

- Keep each library in its own folder (e.g. as submodules)
- Use `arduino-cli`'s `--libraries` flag to tell it where to find them

**Example:**
```bash
arduino-cli compile --fqbn esp32:esp32:esp32 ./my-sketch --libraries ./sensors,./comms,./interfaces
```

This method avoids the need to copy libraries into system folders and is ideal for collaborative or CI-based development.

---

## Library Compilation Rules

- All code must be inside the `src/` folder. Files outside `src/` are ignored during compilation.
- The main `.h` file is included in user sketches using angle brackets (`#include <LibraryName.h>`).
- If a `.cpp` file uses another `.h` file from the same library, it should use relative includes (e.g., `#include "Helper.h"`).

---

## How Arduino CLI Finds and Compiles Libraries

1. The sketch being compiled is inspected to find all `#include` directives.
2. Arduino CLI looks through the `--libraries` paths or global libraries folder to find matching `library.properties` files.
3. Only the libraries whose headers are explicitly included will be compiled.
4. If a library depends on another, you must either:
   - Add both libraries via `--libraries`
   - Declare the dependency in `library.properties` using `depends=OtherLibraryName`

---

## Best Practices for Arduino Libraries

| Practice | Reason |
|---------|--------|
| Keep all source code in `src/` | Required for Arduino CLI compatibility |
| Use header guards (`#ifndef`) | Prevents multiple inclusion errors |
| Keep `library.properties` accurate | Required for metadata and IDE usage |
| Avoid putting `setup()` or `loop()` in libraries (ie any .ino files) | These are meant to be defined in sketches only |
| Avoid side effects in global constructors | Defer hardware initialisation to `begin()` or `setup()` |
| Separate interface and implementation | Encourages modular and testable code |

---

## Using Interfaces in Libraries (RECOMMENDED)

In advanced systems (such as ours), **interfaces** are used to decouple components. Interfaces should:

- Be placed in a minimal, standalone library (like your `interfaces/` submodule)
- Contain only header files (`.h`)
- Have no implementation logic
- Be included in both implementing and consuming modules

**Example:**
```cpp
// In interfaces/src/CommsOutInterface.h
class CommsOutInterface {
public:
    virtual void send(const String& name, float value) = 0;
    virtual ~CommsOutInterface() = default;
};
```

This pattern allows for reusable, mockable, and testable code.

---

## Summary

- Arduino libraries follow a specific structure to ensure compatibility with Arduino CLI and IDEs.
- The `src/` folder must contain all relevant source files.
- The `library.properties` file defines metadata and is mandatory.
- Libraries can be installed globally or linked locally using `arduino-cli`.
- Interfaces should be defined in their own shared library when used across modules.
- Proper library structuring is key to writing reusable, scalable, and maintainable firmware.

---

For additional information, see:
- [Arduino Library Specification](https://arduino.github.io/arduino-cli/latest/library-specification/)
- [Arduino CLI Documentation](https://arduino.github.io/arduino-cli)

