import asyncio
from cua import Sandbox, Image


async def test_sandbox():
    # name must match the existing lume VM -> LumeRuntime reuses the running VM
    # (no clone/pull). Image.macos() only selects the Lume runtime.
    sb = await Sandbox.create(Image.macos(), name="tendril-mac", local=True)
    try:
        screenshot = await sb.screenshot()
        with open("screenshots/test-screenshot.png", "wb") as f:
            f.write(screenshot)
        print("Screenshot saved to screenshots/test-screenshot.png")
    finally:
        await sb.disconnect()  # leaves the VM running


def main():
    asyncio.run(test_sandbox())

if __name__ == "__main__":
    main()
