import json
import unittest

import httpx

from app.schemas.inventory import MultiExtractFromImageResponse
from app.services.find_pipeline import (
    FindPipelineClient,
    FindPipelineError,
    map_find_result,
)


def _item(**overrides):
    item = {
        "item_id": "it_0002",
        "identity": {
            "name": "micro servo",
            "category": "motor",
            "vendor": "goBILDA",
            "sku": "2000-0025-0502",
            "confidence": 0.94,
            "unknown": False,
            "reasoning": "A compact servo with a printed manufacturer label.",
        },
        "barcode": {
            "value": "810069810123",
            "symbology": "CODE_128",
            "confidence": 0.99,
        },
        "ocr": {"text": "2000-0025-0502", "mean_conf": 0.91},
        "dimensions": {
            "obb_mm": [40.2, 20.1],
            "confidence": "high",
            "unit": "mm",
        },
        "errors": [],
        "reference": None,
    }
    item.update(overrides)
    return item


class FindResultMappingTests(unittest.TestCase):
    def test_maps_find_identity_barcode_ocr_and_measurement(self):
        mapped = map_find_result({"items": [_item()]})

        parsed = MultiExtractFromImageResponse.model_validate(mapped)
        self.assertEqual(parsed.summary.total_detected, 1)
        self.assertEqual(parsed.summary.categories, {"Robot Parts": 1})
        item = parsed.items[0]
        self.assertEqual(item.name, "micro servo")
        self.assertEqual(item.category, "Robot Parts")
        self.assertEqual(item.brand, "goBILDA")
        self.assertEqual(item.part_number, "2000-0025-0502")
        self.assertEqual(item.barcode, "810069810123")
        self.assertEqual(item.quantity, 1)
        self.assertIn("Measured 40.2 × 20.1 mm", item.notes or "")
        self.assertIn("Visible text: 2000-0025-0502", item.notes or "")

    def test_unknown_and_partial_items_remain_reviewable(self):
        unknown = _item(
            identity={
                "name": "",
                "category": "other",
                "vendor": "",
                "sku": "",
                "confidence": 0.2,
                "unknown": True,
                "reasoning": "",
            },
            barcode=None,
            ocr=None,
            dimensions=None,
            errors=["ocr_hard: timeout"],
        )
        mapped = map_find_result({"partial": True, "items": [unknown]})

        parsed = MultiExtractFromImageResponse.model_validate(mapped)
        self.assertEqual(parsed.items[0].name, "Unidentified item")
        self.assertEqual(parsed.items[0].category, "Other")
        self.assertEqual(parsed.items[0].confidence, 0.2)
        self.assertIn("review this item", parsed.items[0].notes or "")

    def test_reference_items_are_excluded(self):
        reference = _item(reference={"kind": "ruler"})
        mapped = map_find_result({"items": [reference, _item()]})
        self.assertEqual(mapped["summary"]["total_detected"], 1)


class FindPipelineClientTests(unittest.IsolatedAsyncioTestCase):
    async def test_runs_pipeline_polls_result_and_cleans_up(self):
        requests: list[httpx.Request] = []
        poll_count = 0

        async def handler(request: httpx.Request) -> httpx.Response:
            nonlocal poll_count
            requests.append(request)
            self.assertEqual(request.headers.get("authorization"), "Bearer test-key")
            if request.method == "POST" and request.url.path == "/v1/jobs":
                return httpx.Response(202, json={"job_id": "job_test"})
            if request.method == "POST" and request.url.path == "/v1/jobs/job_test/run":
                body = json.loads(request.content)
                self.assertEqual(
                    body["params"]["segment"],
                    {"background": "depth", "vlm_proposals": "qwen3vl"},
                )
                return httpx.Response(202, json={"state": "QUEUED"})
            if request.method == "GET" and request.url.path == "/v1/jobs/job_test":
                poll_count += 1
                return httpx.Response(
                    200,
                    json={
                        "state": "MEASURED" if poll_count > 1 else "SEGMENTED",
                        "done": poll_count > 1,
                    },
                )
            if request.method == "GET" and request.url.path == "/v1/jobs/job_test/result":
                return httpx.Response(200, json={"items": [_item()]})
            if request.method == "DELETE" and request.url.path == "/v1/jobs/job_test":
                return httpx.Response(204)
            return httpx.Response(404)

        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
            client = FindPipelineClient(
                base_url="https://find.test",
                api_key="test-key",
                poll_interval_seconds=0,
                client=http,
            )
            result = await client.extract(
                filename="parts.jpg",
                image_bytes=b"jpeg-bytes",
            )

        self.assertEqual(result["items"][0]["name"], "micro servo")
        self.assertEqual(poll_count, 2)
        self.assertEqual(requests[-1].method, "DELETE")

    async def test_failed_job_raises_user_facing_error_and_cleans_up(self):
        deleted = False

        async def handler(request: httpx.Request) -> httpx.Response:
            nonlocal deleted
            if request.method == "POST" and request.url.path == "/v1/jobs":
                return httpx.Response(202, json={"job_id": "job_failed"})
            if request.method == "POST":
                return httpx.Response(202, json={})
            if request.method == "GET":
                return httpx.Response(200, json={"state": "FAILED", "done": False})
            if request.method == "DELETE":
                deleted = True
                return httpx.Response(204)
            return httpx.Response(404)

        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
            client = FindPipelineClient(
                base_url="https://find.test", api_key="test-key", client=http
            )
            with self.assertRaises(FindPipelineError) as caught:
                await client.extract(filename="parts.jpg", image_bytes=b"jpeg")
        self.assertEqual(caught.exception.status_code, 422)
        self.assertTrue(deleted)

    async def test_timeout_is_bounded_and_attempts_cleanup(self):
        deleted = False

        async def handler(request: httpx.Request) -> httpx.Response:
            nonlocal deleted
            if request.method == "POST" and request.url.path == "/v1/jobs":
                return httpx.Response(202, json={"job_id": "job_slow"})
            if request.method == "POST":
                return httpx.Response(202, json={})
            if request.method == "GET":
                return httpx.Response(200, json={"state": "SEGMENTED", "done": False})
            if request.method == "DELETE":
                deleted = True
                return httpx.Response(409)
            return httpx.Response(404)

        async with httpx.AsyncClient(transport=httpx.MockTransport(handler)) as http:
            client = FindPipelineClient(
                base_url="https://find.test",
                api_key="test-key",
                job_timeout_seconds=0,
                poll_interval_seconds=0,
                client=http,
            )
            with self.assertRaises(FindPipelineError) as caught:
                await client.extract(filename="parts.jpg", image_bytes=b"jpeg")
        self.assertEqual(caught.exception.status_code, 504)
        self.assertTrue(deleted)

    async def test_upstream_statuses_have_safe_messages(self):
        expected = {
            400: 422,
            401: 503,
            429: 503,
            503: 503,
        }
        for upstream_status, application_status in expected.items():
            async def handler(
                request: httpx.Request, status: int = upstream_status
            ) -> httpx.Response:
                return httpx.Response(status, json={"detail": "sensitive upstream detail"})

            async with httpx.AsyncClient(
                transport=httpx.MockTransport(handler)
            ) as http:
                client = FindPipelineClient(
                    base_url="https://find.test", api_key="test-key", client=http
                )
                with self.assertRaises(FindPipelineError) as caught:
                    await client.extract(filename="parts.jpg", image_bytes=b"jpeg")
            self.assertEqual(caught.exception.status_code, application_status)
            self.assertNotIn("sensitive", caught.exception.public_message)

    async def test_public_plain_http_is_rejected(self):
        with self.assertRaises(FindPipelineError) as caught:
            FindPipelineClient(
                base_url="http://pipeline.example.com", api_key="test-key"
            )
        self.assertIn("secure pipeline", caught.exception.public_message)

    async def test_public_plain_http_requires_explicit_opt_in(self):
        client = FindPipelineClient(
            base_url="http://pipeline.example.com",
            api_key="test-key",
            allow_insecure_http=True,
        )
        self.assertEqual(client.base_url, "http://pipeline.example.com")


if __name__ == "__main__":
    unittest.main()
