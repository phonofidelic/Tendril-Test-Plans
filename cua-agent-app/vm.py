"""Connection glue for the target VM.

Thin wrappers around the cua SDK — no custom input/screen primitives. The CLI
in main.py calls sb.screenshot / sb.mouse.* / sb.keyboard.* / sb.get_dimensions
directly.

Two connection modes:
- Lume (default): attach to a local Lume macOS VM by name (LUME_VM_NAME).
- Direct (CUA_HTTP_URL set): connect to a computer-server at that HTTP base
  URL, e.g. a UTM Windows VM running ``python -m computer_server`` on port
  8000. Use http_url, not ws_url: the SDK's WebSocketTransport speaks an
  older protocol than current computer-server and fails on screenshot and
  get_screen_size responses.
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
    if os.environ.get("CUA_HTTP_URL"):
        return os.environ.get("CUA_VM_NAME", "remote-vm")
    return os.environ.get("LUME_VM_NAME", DEFAULT_VM_NAME)


async def connect_sandbox() -> Sandbox:
    """Attach to the running VM (no clone/pull).

    If CUA_HTTP_URL is set, connect straight to that computer-server (any
    guest OS — UTM Windows, remote Linux, ...). Otherwise attach to the local
    Lume macOS VM by name.
    """
    load_env()
    http_url = os.environ.get("CUA_HTTP_URL")
    if http_url:
        return await Sandbox.connect(vm_name(), http_url=http_url)
    return await Sandbox.create(Image.macos(), name=vm_name(), local=True)


async def disconnect_sandbox(sb: Sandbox) -> None:
    """Disconnect from the VM without stopping it."""
    await sb.disconnect()
