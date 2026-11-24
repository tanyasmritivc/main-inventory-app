"""Isolated, bounded process for parsing a single order upload."""

import base64
import json
import resource
import sys


def main():
    resource.setrlimit(resource.RLIMIT_CPU, (12, 14))
    if sys.platform.startswith("linux"):
        ceiling = 768 * 1024 * 1024
        resource.setrlimit(resource.RLIMIT_AS, (ceiling, ceiling))
    from fastapi import HTTPException
    from .supplier_orders import preview

    try:
        request = json.load(sys.stdin.buffer)
        result = preview(
            base64.b64decode(request["data"], validate=True),
            request["filename"],
            request["assignments"],
            request["pasted"],
        )
        output = json.dumps({"result": result}, ensure_ascii=False).encode()
        if len(output) > 12 * 1024 * 1024:
            raise HTTPException(
                413, "This review is too large. Divide the file into smaller orders."
            )
    except HTTPException as exc:
        output = json.dumps({"status": exc.status_code, "detail": exc.detail}).encode()
    except (KeyError, ValueError, OSError, MemoryError):
        output = b'{"status":422,"detail":"The order document could not be read."}'
    sys.stdout.buffer.write(output)


if __name__ == "__main__":
    main()
