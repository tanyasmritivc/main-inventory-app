"""Update the existing live world sidebar to open Connections directly."""
from pathlib import Path
import sys


def patch(frontend: Path):
    navigation = frontend / "src/lib/world-navigation.ts"
    original = navigation.read_text()
    old = 'label: "Connections",\n        route: worldHref(world, "tools") + "#findez-connect",'
    new = 'label: "Connections",\n        route: "/settings/connections",'
    if new in original:
        return
    assert original.count(old) == 1, "Unexpected Connections navigation; inspect before patching"
    navigation.write_text(original.replace(old, new, 1))


if __name__ == "__main__":
    patch(Path(sys.argv[1]))
