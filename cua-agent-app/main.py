"""Thin CLI over the cua Sandbox SDK for the tendril-mac Lume VM.

Each subcommand connects, calls a single cua SDK method
(``sb.screenshot`` / ``sb.mouse.*`` / ``sb.keyboard.*`` / ``sb.get_dimensions``),
then disconnects. No custom input or coordinate primitives — the SDK owns those.
See https://cua.ai/docs/cua/guide/get-started/what-is-cua
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

from vm import connect_sandbox, disconnect_sandbox, vm_name


async def cmd_dimensions() -> None:
    sb = await connect_sandbox()
    try:
        width, height = await sb.get_dimensions()
        print(f"{width}x{height}")
    finally:
        await disconnect_sandbox(sb)


async def cmd_screenshot(out: Path) -> None:
    sb = await connect_sandbox()
    try:
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(await sb.screenshot())
        width, height = await sb.get_dimensions()
        print(f"Screenshot saved to {out} (screen {width}x{height})")
    finally:
        await disconnect_sandbox(sb)


async def cmd_click(x: int, y: int) -> None:
    sb = await connect_sandbox()
    try:
        await sb.mouse.click(x, y)
        print(f"Clicked ({x}, {y}) on {vm_name()}")
    finally:
        await disconnect_sandbox(sb)


async def cmd_double_click(x: int, y: int) -> None:
    sb = await connect_sandbox()
    try:
        await sb.mouse.double_click(x, y)
        print(f"Double-clicked ({x}, {y}) on {vm_name()}")
    finally:
        await disconnect_sandbox(sb)


async def cmd_right_click(x: int, y: int) -> None:
    sb = await connect_sandbox()
    try:
        await sb.mouse.right_click(x, y)
        print(f"Right-clicked ({x}, {y}) on {vm_name()}")
    finally:
        await disconnect_sandbox(sb)


async def cmd_move(x: int, y: int) -> None:
    sb = await connect_sandbox()
    try:
        await sb.mouse.move(x, y)
        print(f"Moved cursor to ({x}, {y}) on {vm_name()}")
    finally:
        await disconnect_sandbox(sb)


async def cmd_drag(x1: int, y1: int, x2: int, y2: int) -> None:
    sb = await connect_sandbox()
    try:
        await sb.mouse.drag(x1, y1, x2, y2)
        print(f"Dragged ({x1}, {y1}) -> ({x2}, {y2}) on {vm_name()}")
    finally:
        await disconnect_sandbox(sb)


async def cmd_scroll(x: int, y: int, dy: int) -> None:
    sb = await connect_sandbox()
    try:
        await sb.mouse.scroll(x, y, scroll_y=dy)
        print(f"Scrolled at ({x}, {y}) dy={dy} on {vm_name()}")
    finally:
        await disconnect_sandbox(sb)


async def cmd_type(text: str) -> None:
    sb = await connect_sandbox()
    try:
        await sb.keyboard.type(text)
        print(f"Typed {len(text)} character(s) on {vm_name()}")
    finally:
        await disconnect_sandbox(sb)


async def cmd_keypress(keys: list[str]) -> None:
    sb = await connect_sandbox()
    try:
        await sb.keyboard.keypress(keys)
        print(f"Pressed {keys!r} on {vm_name()}")
    finally:
        await disconnect_sandbox(sb)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Thin CLI over the cua Sandbox SDK for the tendril-mac Lume VM.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("dimensions", help="Print screen size via sb.get_dimensions()")

    p_shot = sub.add_parser("screenshot", help="Capture the VM screen (sb.screenshot)")
    p_shot.add_argument(
        "--out",
        type=Path,
        default=Path("screenshots/screenshot.png"),
        help="Output PNG path (default: screenshots/screenshot.png)",
    )

    p_click = sub.add_parser("click", help="Left-click (sb.mouse.click)")
    p_click.add_argument("--x", type=int, required=True)
    p_click.add_argument("--y", type=int, required=True)

    p_dclick = sub.add_parser("double-click", help="Double-click (sb.mouse.double_click)")
    p_dclick.add_argument("--x", type=int, required=True)
    p_dclick.add_argument("--y", type=int, required=True)

    p_rclick = sub.add_parser("right-click", help="Right-click (sb.mouse.right_click)")
    p_rclick.add_argument("--x", type=int, required=True)
    p_rclick.add_argument("--y", type=int, required=True)

    p_move = sub.add_parser("move", help="Move cursor (sb.mouse.move)")
    p_move.add_argument("--x", type=int, required=True)
    p_move.add_argument("--y", type=int, required=True)

    p_drag = sub.add_parser("drag", help="Drag from one point to another (sb.mouse.drag)")
    p_drag.add_argument("--x1", type=int, required=True)
    p_drag.add_argument("--y1", type=int, required=True)
    p_drag.add_argument("--x2", type=int, required=True)
    p_drag.add_argument("--y2", type=int, required=True)

    p_scroll = sub.add_parser("scroll", help="Scroll (sb.mouse.scroll)")
    p_scroll.add_argument("--x", type=int, required=True)
    p_scroll.add_argument("--y", type=int, required=True)
    p_scroll.add_argument(
        "--dy",
        type=int,
        default=-3,
        help="Vertical scroll amount (negative = down, default: -3)",
    )

    p_type = sub.add_parser("type", help="Type text (sb.keyboard.type)")
    p_type.add_argument("--text", required=True, help="Text to type")

    p_keys = sub.add_parser("keypress", help="Press key combo (sb.keyboard.keypress)")
    p_keys.add_argument(
        "--keys",
        required=True,
        help='Keys to press, e.g. "enter" or "cmd,space"',
    )

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "dimensions":
            asyncio.run(cmd_dimensions())
        elif args.command == "screenshot":
            asyncio.run(cmd_screenshot(args.out))
        elif args.command == "click":
            asyncio.run(cmd_click(args.x, args.y))
        elif args.command == "double-click":
            asyncio.run(cmd_double_click(args.x, args.y))
        elif args.command == "right-click":
            asyncio.run(cmd_right_click(args.x, args.y))
        elif args.command == "move":
            asyncio.run(cmd_move(args.x, args.y))
        elif args.command == "drag":
            asyncio.run(cmd_drag(args.x1, args.y1, args.x2, args.y2))
        elif args.command == "scroll":
            asyncio.run(cmd_scroll(args.x, args.y, args.dy))
        elif args.command == "type":
            asyncio.run(cmd_type(args.text))
        elif args.command == "keypress":
            keys = [k.strip() for k in args.keys.split(",") if k.strip()]
            asyncio.run(cmd_keypress(keys))
        else:
            parser.error(f"unknown command: {args.command}")
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
