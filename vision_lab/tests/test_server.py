import copy
import http.client
import json
import tempfile
import threading
import unittest
from pathlib import Path

from PIL import Image

from findez_vision.data import file_hash, read_json
from findez_vision.demo import create_demo
from findez_vision.server import make_server


class ServerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = create_demo(Path(self.tmp.name)/"demo")
        self.server = make_server(self.root/"dataset.json", 0)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.stop)
        self.host = f"127.0.0.1:{self.server.server_port}"
        _, _, body = self.request("GET", "/session")
        self.session = json.loads(body)

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(self, method, path, body=None, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.server.server_port, timeout=3)
        try:
            connection.request(method, path, body=body, headers=headers or {})
            response = connection.getresponse()
            return response.status, dict(response.getheaders()), response.read()
        finally:
            connection.close()

    def payload(self):
        sample = self.session["dataset"]["samples"][0]
        annotation = copy.deepcopy(sample["annotation"])
        annotation["reviewer"] = "Local reviewer"
        return {"sample_id":sample["id"], "revision":self.session["revision"], "annotation":annotation}

    def save(self, payload, headers=None):
        valid = {"Content-Type":"application/json", "Origin":"http://"+self.host,
                 "X-Vision-Token":self.session["token"]}
        if headers:
            valid.update(headers)
        return self.request("POST", "/annotation", json.dumps(payload), valid)

    def test_loopback_binding_and_security_headers(self):
        self.assertEqual(self.server.server_address[0], "127.0.0.1")
        status, headers, _ = self.request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn("frame-ancestors 'none'", headers["Content-Security-Policy"])
        self.assertEqual(headers["Cache-Control"], "no-store")
        self.assertNotIn("Access-Control-Allow-Origin", headers)

    def test_host_origin_and_token_checks(self):
        self.assertEqual(self.request("GET", "/session", headers={"Host":"evil.test"})[0], 403)
        for headers in ({"Origin":"https://evil.test"}, {"X-Vision-Token":""}, {"Host":"localhost"}):
            with self.subTest(headers=headers):
                self.assertEqual(self.save(self.payload(), headers)[0], 403)

    def test_save_persists_with_history_and_stale_revision_conflicts(self):
        payload = self.payload()
        status, _, body = self.save(payload)
        self.assertEqual(status, 200, body)
        saved = read_json(self.root/"dataset.json")
        self.assertEqual(saved["samples"][0]["annotation"]["reviewer"], "Local reviewer")
        self.assertEqual(len(list((self.root/".history").glob("*.json"))), 1)
        self.assertEqual(self.save(payload)[0], 409)

    def test_invalid_save_does_not_change_dataset(self):
        before = (self.root/"dataset.json").read_bytes()
        payload = self.payload()
        payload["annotation"]["objects"][0]["polygons"] = [[[0,0],[100,0],[5,5]]]
        self.assertEqual(self.save(payload)[0], 400)
        self.assertEqual(before, (self.root/"dataset.json").read_bytes())
        self.assertFalse((self.root/".history").exists())

    def test_origin_cannot_be_laundered_by_verifying_model_labels(self):
        data = read_json(self.root/"dataset.json")
        data["samples"][0]["annotation"]["label_origin"] = "model_assisted"
        (self.root/"dataset.json").write_text(json.dumps(data))
        self.session = json.loads(self.request("GET", "/session")[2])
        payload = self.payload()
        payload["annotation"]["label_origin"] = "independent_human"
        status, _, body = self.save(payload)
        self.assertEqual(status, 200, body)
        self.assertEqual(json.loads(body)["annotation"]["label_origin"], "model_assisted")

    def test_binary_masks_are_read_only_in_polygon_editor(self):
        data = read_json(self.root/"dataset.json")
        sample = data["samples"][0]
        mask = self.root/"binary.png"
        im = Image.new("L", (64,48))
        im.paste(255, (8,10,28,35))
        im.save(mask)
        obj = sample["annotation"]["objects"][0]
        del obj["polygons"]
        obj["mask"] = {"path":"binary.png", "sha256":file_hash(mask)}
        (self.root/"dataset.json").write_text(json.dumps(data))
        self.session = json.loads(self.request("GET", "/session")[2])
        status, _, body = self.save(self.payload())
        self.assertEqual(status, 400)
        self.assertIn("read-only", json.loads(body)["error"])

    def test_no_arbitrary_file_read_or_write_routes(self):
        for path in ("/dataset.json", "/grants.json", "/../../etc/passwd", "/image/..%2Fdataset.json"):
            with self.subTest(path=path):
                self.assertEqual(self.request("GET", path)[0], 404)
        self.assertEqual(self.request("GET", "/image/scene_0")[0], 200)
        self.assertEqual(self.request("PUT", "/annotation", "{}")[0], 501)

    def test_input_size_limit_and_unknown_sample(self):
        payload = self.payload()
        payload["sample_id"] = "missing"
        self.assertEqual(self.save(payload)[0], 404)
        self.assertEqual(self.save(payload, {"Content-Length":"1000001"})[0], 413)

    def test_browser_import_and_existing_annotation_persistence(self):
        from test_imports import photo_body
        payload = {**photo_body(), "revision":self.session["revision"]}
        headers = {"Content-Type":"application/json", "Origin":"http://"+self.host,
                   "X-Vision-Token":self.session["token"]}
        status, _, body = self.request("POST", "/images", json.dumps(payload), headers)
        self.assertEqual(status, 200, body)
        result = json.loads(body)
        self.assertFalse(result["permission_granted"])
        data = read_json(self.root/"dataset.json")
        self.assertEqual(len(data["samples"]), 5)
        self.assertEqual(data["samples"][0], self.session["dataset"]["samples"][0])
        self.assertEqual(self.request("GET", "/image/"+result["sample"]["id"])[0], 200)
        self.assertEqual(self.request("POST", "/images", json.dumps(payload), headers)[0], 409)
        payload["revision"] = result["revision"]
        self.assertEqual(self.request("POST", "/images", json.dumps(payload),
                                     {**headers,"Origin":"https://evil.test"})[0], 403)


if __name__ == "__main__":
    unittest.main()
