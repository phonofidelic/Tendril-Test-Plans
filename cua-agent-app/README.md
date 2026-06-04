# cua-agent-app

A minimal [Computer Use Agent (CUA)](https://github.com/trycua/cua) example that connects to a local macOS virtual machine, captures a screenshot, and saves it to disk.

It uses the [`cua`](https://pypi.org/project/cua/) Python SDK with the **Lume** runtime to reuse an already-running local Lume VM (no clone or pull) instead of provisioning a new sandbox.

## Requirements

- macOS (Apple Silicon) with [Lume](https://github.com/trycua/cua) installed and running
- A running Lume VM named `tendril-mac`
- Python `>=3.12,<3.14`
- [`uv`](https://docs.astral.sh/uv/) for dependency management

## Setup

Install dependencies into a virtual environment:

```bash
uv sync
```

Make sure the target Lume VM is running before you start the app. The name passed to `Sandbox.create(...)` must match the existing VM:

```bash
lume ls
lume run tendril-mac
```

## Usage

Run the app:

```bash
uv run main.py
```

On success it writes a screenshot of the VM's current screen to `screenshots/test-screenshot.png` and prints:

```
Screenshot saved to screenshots/test-screenshot.png
```

## How it works

`main.py` does the following:

1. Connects to the existing local Lume VM via `Sandbox.create(Image.macos(), name="tendril-mac", local=True)`. `Image.macos()` only selects the Lume runtime, so the running VM is reused rather than re-provisioned.
2. Captures a screenshot with `sb.screenshot()` and writes the bytes to `screenshots/test-screenshot.png`.
3. Calls `sb.disconnect()`, which leaves the VM running.

## Project structure

```
cua-agent-app/
├── main.py              # Entry point: connects to the VM and takes a screenshot
├── pyproject.toml       # Project metadata and dependencies
├── uv.lock              # Locked dependency versions
└── screenshots/         # Output directory for captured screenshots
```
