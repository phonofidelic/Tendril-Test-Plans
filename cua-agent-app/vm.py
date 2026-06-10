"""Connection glue for the Lume macOS VM.

Thin wrappers around the cua SDK — no custom input/screen primitives. The CLI
in main.py calls sb.screenshot / sb.mouse.* / sb.keyboard.* / sb.get_dimensions
directly.
"""

from __future__ import annotations

import os
from pathlib import Path

from cua import Image, Sandbox

DEFAULT_VM_NAME = "tendril-mac"


def load_env() -> None:
    """Load .env from repo root or cwd into os.environ (does not override existing)."""
    candidates = [
        Path(__file__).resolve().parent.parent / ".env",
        Path.cwd() / ".env",
        Path(__file__).resolve().parent / ".env",
    ]
    for path in candidates:
        if not path.is_file():
            continue
        for line in path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip("'").strip('"')
            os.environ.setdefault(key, value)
        break


def vm_name() -> str:
    load_env()
    return os.environ.get("LUME_VM_NAME", DEFAULT_VM_NAME)


async def connect_sandbox() -> Sandbox:
    """Attach to the running Lume VM (no clone/pull)."""
    load_env()
    return await Sandbox.create(Image.macos(), name=vm_name(), local=True)


async def disconnect_sandbox(sb: Sandbox) -> None:
    """Disconnect from the VM without stopping it."""
    await sb.disconnect()
