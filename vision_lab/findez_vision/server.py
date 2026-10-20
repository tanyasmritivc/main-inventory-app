"""Loopback-only annotation UI. No production credentials, proxying or uploads."""
import hmac
import json
import os
import secrets
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

from .data import Invalid, digest, load_dataset, read_json, safe_file, validate_annotation, validate_dataset


def make_server(dataset_path, port=8790):
    dataset_path = Path(dataset_path).resolve()
    load_dataset(dataset_path)
    token, lock = secrets.token_urlsafe(32), threading.Lock()
    web = Path(__file__).parent/"web"

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        @property
        def origin(self):
            return f"http://127.0.0.1:{self.server.server_port}"

        def respond(self, status, body, content_type="application/json"):
            if isinstance(body, (dict, list)):
                body = json.dumps(body, ensure_ascii=False).encode()
            elif isinstance(body, str):
                body = body.encode()
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Security-Policy",
                             "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
            self.end_headers()
            self.wfile.write(body)

        def host_allowed(self):
            return self.headers.get("Host") == urlsplit(self.origin).netloc

        def do_GET(self):
            if not self.host_allowed():
                return self.respond(403, {"error": "Use the printed 127.0.0.1 address."})
            path = urlsplit(self.path).path
            try:
                if path in ("/", "/app.js", "/style.css"):
                    name, content = {"/": ("index.html", "text/html; charset=utf-8"),
                                     "/app.js": ("app.js", "text/javascript; charset=utf-8"),
                                     "/style.css": ("style.css", "text/css; charset=utf-8")}[path]
                    return self.respond(200, (web/name).read_bytes(), content)
                if path == "/session":
                    with lock:
                        data = load_dataset(dataset_path)
                    return self.respond(200, {"dataset": data, "revision": digest(data), "token": token})
                if path.startswith("/image/"):
                    sid = unquote(path.removeprefix("/image/"))
                    data = read_json(dataset_path)
                    sample = next((s for s in data["samples"] if s["id"] == sid), None)
                    if sample:
                        image = safe_file(dataset_path.parent, sample["image"]["path"])
                        return self.respond(200, image.read_bytes(), "image/png" if image.suffix.lower() == ".png" else "image/jpeg")
                self.respond(404, {"error": "Not found"})
            except (Invalid, ValueError, OSError):
                self.respond(400, {"error": "Dataset is unavailable or changed. Run validate before reopening."})

        def do_POST(self):
            if (not self.host_allowed() or self.headers.get("Origin") != self.origin or
                not hmac.compare_digest(self.headers.get("X-Vision-Token", ""), token)):
                return self.respond(403, {"error": "Local session check failed. Reload this page."})
            if self.path != "/annotation" or self.headers.get("Content-Type") != "application/json":
                return self.respond(400, {"error": "Unsupported request"})
            try:
                size = int(self.headers.get("Content-Length", "0"))
                if not 0 < size <= 1_000_000:
                    return self.respond(413, {"error": "Annotation is too large"})
                body = json.loads(self.rfile.read(size))
                if not isinstance(body, dict):
                    raise Invalid("Expected an annotation object")
                with lock:
                    data = load_dataset(dataset_path)
                    if body.get("revision") != digest(data):
                        return self.respond(409, {"error": "Another edit changed this dataset. Reload before saving."})
                    sample = next((s for s in data["samples"] if s["id"] == body.get("sample_id")), None)
                    if sample is None:
                        return self.respond(404, {"error": "Sample not found"})
                    annotation = body.get("annotation")
                    # Review provenance is generated here, not accepted as an arbitrary source.
                    if not isinstance(annotation, dict):
                        raise Invalid("Missing annotation")
                    if any("mask" in obj for obj in sample["annotation"]["objects"]):
                        raise Invalid("Binary-mask samples are read-only in this polygon editor")
                    annotation["source"] = "synthetic" if sample["provenance"]["source_type"] == "synthetic" else "human"
                    # Editing or verifying a model-assisted label does not erase its origin.
                    annotation["label_origin"] = sample["annotation"]["label_origin"]
                    annotation["reviewed_at"] = datetime.now(timezone.utc).isoformat()
                    validate_annotation(annotation, (sample["image"]["width"], sample["image"]["height"]), dataset_path.parent)
                    before = json.loads(json.dumps(data))
                    sample["annotation"] = annotation
                    validate_dataset(data, dataset_path.parent)
                    history = dataset_path.parent/".history"
                    history.mkdir(exist_ok=True)
                    backup = history/(digest(before)+".json")
                    if not backup.exists():
                        with backup.open("x") as stream:
                            json.dump(before, stream, indent=2)
                    temp = dataset_path.with_name("."+dataset_path.name+"."+secrets.token_hex(8)+".tmp")
                    try:
                        with temp.open("x") as stream:
                            json.dump(data, stream, indent=2, allow_nan=False)
                            stream.write("\n")
                            stream.flush()
                            os.fsync(stream.fileno())
                        os.replace(temp, dataset_path)
                    finally:
                        temp.unlink(missing_ok=True)
                self.respond(200, {"revision": digest(data), "annotation": annotation})
            except (Invalid, ValueError, TypeError, OSError) as exc:
                self.respond(400, {"error": str(exc) if isinstance(exc, Invalid) else "Invalid annotation; nothing was saved."})

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)
