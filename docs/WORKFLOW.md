# Development Workflow

This document outlines the recommended workflow for contributing to the `esp32-propulsion` firmware repository and its associated submodules (`sensors`, `comms`, and `interfaces`).

## Overview

The firmware is structured to follow modular, decoupled design principles. It consists of three interdependent submodules and one main integration layer:

- **sensors/**: Manages sensor configuration, polling, and data retrieval.
- **comms/**: Provides communication output logic.
- **interfaces/**: Contains shared interface definitions to decouple `sensors` from `comms`.
- **propulsion-firmware/**: Main Arduino sketch integrating components.

Each submodule is maintained independently and should remain reusable and testable in isolation.

---

## General Workflow Guidelines

### 1. Clone with Submodules

When cloning the repository, always use:

```bash
git clone <repo-url / repo-ssh>
```

---

### 2. Making Changes in Submodules

Each submodule (`sensors`, `comms`, `interfaces`) is versioned independently. When making changes, contributors must:

- Create a branch inside the relevant submodule
- Commit and push changes within the submodule
- Update the submodule reference from the root main repo

Example workflow for modifying `comms`:

```bash
cd comms
git checkout -b feature/update-comms-out
# make changes, commit, push
cd ..
git add comms
git commit -m "Update comms submodule to latest commit"
git push
```

---

## Coordinating Interface Changes

If you are modifying a class in `comms` that is used by `sensors` (e.g., `CommsOut`), and that class is abstracted via the `interfaces` module, you must:

1. **Update the relevant interface in `interfaces/`**
2. **Make corresponding changes in `comms/` to match the interface**
3. **Ensure that any modules depending on the interface still compile and behave correctly**
4. **Update all three submodules in the main repo to their latest versions**

This ensures consistency and avoids interface mismatches.

---

## When to Modify Each Module

| Module       | Purpose                                              | When to Modify                                      |
|--------------|------------------------------------------------------|-----------------------------------------------------|
| `interfaces` | Defines shared contracts between components          | When changing public methods used across modules    |
| `comms`      | Implements `CommsOutInterface`, handles data output  | When changing how data is sent (e.g., Serial, BLE)  |
| `sensors`    | Implements sensor logic and `SensorManager`          | When adding/removing sensor types or polling logic  |
| `propulsion-firmware` | Ties everything together and manages flow | When integrating features or wiring new components  |

---

## Build and Test

To build the firmware:

```bash
./build.sh
```

To build without uploading:

```bash
./build.sh --no-upload
```

Ensure all changes are validated through a successful build before committing or opening a pull request.

---

## Submodule Policy

- Do not duplicate interface definitions across submodules.
- Keep `interfaces` minimal and abstract-only.
- Do not include implementation logic in `interfaces`.
- Always reference submodules by commit, not branch, to ensure reproducibility.
