"""Read-only docs checks; run with backend Python after building the web app.

From repository root:
    backend/venv/bin/python frontend/scripts/verify-api-docs.py

No API requests are made. Examples are syntax-checked, never executed.
Use an OpenAPI 3.1 validator separately for specification validation.
"""

import ast
import json
import re
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(root / "backend"))

from fastapi import FastAPI  # noqa: E402
from app.api.routes import api_v1  # noqa: E402


def main():
    app = FastAPI()
    app.include_router(api_v1.router)
    actual = app.openapi()
    saved = json.loads((root / "frontend/src/lib/api-request-schemas.json").read_text())
    for name, schema in saved.items():
        assert actual["components"]["schemas"][name] == schema, f"Request schema drift: {name}"

    build = root / "frontend/.next/server/app/docs/api"
    spec = json.loads((build / "openapi.json.body").read_text())
    implemented = {(method, path.removeprefix("/api/v1")) for path, methods in actual["paths"].items() for method in methods}
    documented = {(method, path) for path, methods in spec["paths"].items() for method in methods}
    assert implemented == documented, "Endpoint documentation drift"
    requests = 0
    for methods in spec["paths"].values():
        for operation in methods.values():
            content = operation.get("requestBody", {}).get("content", {}).get("application/json")
            if content:
                model = getattr(api_v1, content["schema"]["$ref"].split("/")[-1])
                model.model_validate(content["example"])
                requests += 1

    guide = (build / "guide.md.body").read_text()
    for language, code in re.findall(r"```(\w+)\n(.*?)\n```", guide, re.S):
        if language == "python":
            ast.parse(code)
        elif language == "javascript":
            subprocess.run(["node", "--input-type=module", "--check"], input=code, text=True, check=True)
        elif language in {"bash", "shell"}:
            subprocess.run(["bash", "-n"], input=code, text=True, check=True)
        elif language == "json":
            value = json.loads(code)
            if "filters" in value:
                api_v1.InventoryQuery.model_validate(value)
    print(f"PASS: {len(documented)} endpoints, {len(saved)} backend schemas, {requests} request examples, and sample syntax")


if __name__ == "__main__":
    main()
