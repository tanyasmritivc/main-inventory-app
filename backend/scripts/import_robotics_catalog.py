"""Import REV Robotics and goBILDA products from their official public catalogs.

The command is dry-run by default. Use ``--apply`` only in an environment with
the production Supabase credentials available.
"""

from __future__ import annotations

import argparse
import html
import json
import logging
import re
import time
from dataclasses import dataclass
from html.parser import HTMLParser
from typing import Iterable
from urllib.parse import urlparse
from xml.etree import ElementTree

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from app.services.supabase_client import create_supabase_admin


SOURCES = {
    "rev": {
        "brand": "REV Robotics",
        "sitemap": "https://www.revrobotics.com/xmlsitemap.php?type=products&page={page}",
        "host": "www.revrobotics.com",
    },
    "gobilda": {
        "brand": "goBILDA",
        "sitemap": "https://www.gobilda.com/xmlsitemap.php?type=products&page={page}",
        "host": "www.gobilda.com",
    },
}

logger = logging.getLogger(__name__)

_SPACE_RE = re.compile(r"\s+")
_BC_DATA_RE = re.compile(r"var BCData\s*=\s*(\{.*?\});", re.DOTALL)
_CUSTOM_FIELD_RE = re.compile(
    r'(?:\\?"name\\?":\\?"spec_)(.*?)(?:\\?",\\?"value\\?":\\?")(.*?)(?:\\?")'
)


@dataclass(frozen=True)
class CatalogProduct:
    brand: str
    part_number: str
    name: str
    barcode: str | None
    category: str
    subcategory: str | None
    description: str | None
    image_url: str | None
    product_url: str
    specifications: dict[str, str]

    def database_payload(self) -> dict:
        return {
            "barcode": self.barcode or self.part_number,
            "canonical_name": self.name,
            "aliases": [],
            "brand": self.brand,
            "category": self.category,
            "subcategory": self.subcategory,
            "part_number": self.part_number,
            "description": self.description,
            "image_url": self.image_url,
            "source": "manufacturer",
            "verification_status": "verified",
            "product_url": self.product_url,
            "source_url": self.product_url,
            "specifications": self.specifications,
            "compatibility": {},
            "confirmation_count": 1,
            "verified_at": "now()",
        }


class _StructuredDataParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.json_documents: list[object] = []
        self.meta: dict[str, str] = {}
        self._json_buffer: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if tag == "script" and values.get("type") == "application/ld+json":
            self._json_buffer = []
        if tag == "meta" and values.get("itemprop") and values.get("content"):
            self.meta[values["itemprop"]] = values["content"]

    def handle_data(self, data: str) -> None:
        if self._json_buffer is not None:
            self._json_buffer.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag != "script" or self._json_buffer is None:
            return
        raw = "".join(self._json_buffer).strip()
        self._json_buffer = None
        if not raw:
            return
        try:
            self.json_documents.append(json.loads(raw))
        except json.JSONDecodeError:
            return


def _plain_text(value: object) -> str:
    text = re.sub(r"<[^>]+>", " ", str(value or ""))
    return _SPACE_RE.sub(" ", html.unescape(text)).strip()


def _json_objects(document: object) -> Iterable[dict]:
    if isinstance(document, dict):
        yield document
        graph = document.get("@graph")
        if isinstance(graph, list):
            for value in graph:
                if isinstance(value, dict):
                    yield value
    elif isinstance(document, list):
        for value in document:
            if isinstance(value, dict):
                yield value


def _type_is(value: object, wanted: str) -> bool:
    if isinstance(value, list):
        return wanted in value
    return value == wanted


def _breadcrumb_names(documents: list[object]) -> list[str]:
    for document in documents:
        for value in _json_objects(document):
            if not _type_is(value.get("@type"), "BreadcrumbList"):
                continue
            names: list[str] = []
            for entry in value.get("itemListElement") or []:
                item = entry.get("item") if isinstance(entry, dict) else None
                name = item.get("name") if isinstance(item, dict) else None
                if name:
                    names.append(_plain_text(name))
            return names
    return []


def _category_for(breadcrumbs: list[str]) -> tuple[str, str | None]:
    useful = [name for name in breadcrumbs[1:-1] if name]
    joined = " ".join(useful).lower()
    if any(word in joined for word in ("electronic", "control", "sensor", "wiring")):
        category = "Electronics"
    elif any(word in joined for word in ("hardware", "screw", "nut", "fastener", "bearing")):
        category = "Hardware"
    elif "tool" in joined:
        category = "Tools"
    elif any(word in joined for word in ("battery", "charger")):
        category = "Batteries"
    else:
        category = "Robot Parts"
    return category, useful[-1] if useful else None


def _specifications(page: str, description: str, meta: dict[str, str]) -> dict[str, str]:
    specs: dict[str, str] = {}
    if meta.get("weight"):
        specs["weight"] = _plain_text(meta["weight"])

    for raw_name, raw_value in _CUSTOM_FIELD_RE.findall(page):
        name = _plain_text(raw_name.replace("\\u0026", "&").replace("\\/", "/"))
        value = _plain_text(raw_value.replace("\\u0026", "&").replace("\\/", "/"))
        if name and value and len(name) <= 80 and len(value) <= 250:
            specs[name.lower().replace(" ", "_")] = value

    for name, value in re.findall(r"(?:^|\n)([A-Za-z][A-Za-z0-9 #()/.\-]{2,60}):\s*([^\n]{1,120})", description):
        key = _plain_text(name).lower().replace(" ", "_")
        cleaned = _plain_text(value)
        if key and cleaned:
            specs.setdefault(key, cleaned)
        if len(specs) >= 40:
            break
    return specs


def parse_product_page(page: str, *, brand: str, product_url: str) -> CatalogProduct | None:
    parser = _StructuredDataParser()
    parser.feed(page)
    product: dict | None = None
    for document in parser.json_documents:
        for value in _json_objects(document):
            if _type_is(value.get("@type"), "Product") and value.get("sku"):
                product = value
                break
        if product:
            break
    if not product:
        return None

    part_number = _plain_text(product.get("sku"))
    name = _plain_text(product.get("name"))
    if not part_number or not name:
        return None

    barcode = _plain_text(parser.meta.get("gtin")) or None
    match = _BC_DATA_RE.search(page)
    if match:
        try:
            attributes = json.loads(match.group(1)).get("product_attributes") or {}
            barcode = _plain_text(attributes.get("upc") or attributes.get("gtin")) or barcode
        except json.JSONDecodeError:
            pass

    breadcrumbs = _breadcrumb_names(parser.json_documents)
    category, subcategory = _category_for(breadcrumbs)
    description = _plain_text(product.get("description"))
    url = _plain_text(product.get("url")) or product_url
    return CatalogProduct(
        brand=brand,
        part_number=part_number,
        name=name,
        barcode=barcode,
        category=category,
        subcategory=subcategory,
        description=description or None,
        image_url=_plain_text(product.get("image")) or None,
        product_url=url,
        specifications=_specifications(page, html.unescape(str(product.get("description") or "")), parser.meta),
    )


def sitemap_urls(session: requests.Session, template: str, *, max_pages: int = 100) -> list[str]:
    urls: list[str] = []
    for page_number in range(1, max_pages + 1):
        response = session.get(template.format(page=page_number), timeout=60)
        if response.status_code == 404:
            break
        response.raise_for_status()
        root = ElementTree.fromstring(response.content)
        page_urls = [node.text.strip() for node in root.findall("{*}url/{*}loc") if node.text]
        if not page_urls:
            break
        urls.extend(page_urls)
    return list(dict.fromkeys(urls))


def fetch_products(
    source: str,
    *,
    limit: int | None = None,
    delay: float = 1.0,
    session: requests.Session | None = None,
) -> Iterable[CatalogProduct]:
    config = SOURCES[source]
    client = session or requests.Session()
    client.headers["User-Agent"] = "FindEZCatalogSync/1.0 (+https://findez.ai)"
    if session is None:
        retries = Retry(
            total=3,
            backoff_factor=1,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=("GET",),
        )
        client.mount("https://", HTTPAdapter(max_retries=retries))
    urls = sitemap_urls(client, config["sitemap"])
    if limit is not None:
        urls = urls[:limit]
    for index, url in enumerate(urls):
        if urlparse(url).hostname != config["host"]:
            continue
        try:
            response = client.get(url, timeout=60)
            response.raise_for_status()
            parsed = parse_product_page(response.text, brand=config["brand"], product_url=url)
            if parsed:
                yield parsed
            else:
                logger.warning("No product metadata found at %s", url)
        except requests.RequestException as error:
            logger.warning("Skipping unavailable product %s: %s", url, error)
        if delay and index + 1 < len(urls):
            time.sleep(delay)


def upsert_product(product: CatalogProduct) -> str:
    client = create_supabase_admin()
    existing = (
        client.table("parts_catalog")
        .select("catalog_id")
        .eq("verification_status", "verified")
        .ilike("brand", product.brand)
        .ilike("part_number", product.part_number)
        .limit(1)
        .execute()
    )
    payload = product.database_payload()
    payload["verified_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    rows = existing.data or []
    target_catalog_id = rows[0]["catalog_id"] if rows else None
    skipped_barcodes: set[str] = set()

    # Vendor catalogs occasionally publish one UPC for multiple variants. Never
    # overwrite an established mapping: retain the SKU as this row's scan key
    # and leave the ambiguous UPC attached to its first verified owner.
    if product.barcode:
        barcode_owner = (
            client.table("parts_catalog")
            .select("catalog_id,brand,part_number")
            .eq("barcode", product.barcode)
            .limit(1)
            .execute()
        )
        owners = barcode_owner.data or []
        if owners and owners[0].get("catalog_id") != target_catalog_id:
            owner = owners[0]
            skipped_barcodes.add(product.barcode)
            payload["barcode"] = product.part_number
            logger.warning(
                "Ambiguous manufacturer barcode %s: keeping %s %s; %s %s remains SKU-only",
                product.barcode,
                owner.get("brand"),
                owner.get("part_number"),
                product.brand,
                product.part_number,
            )

    if rows:
        catalog_id = target_catalog_id
        update_payload = dict(payload)
        update_payload.pop("aliases", None)
        client.table("parts_catalog").update(update_payload).eq("catalog_id", catalog_id).execute()
        action = "updated"
    else:
        result = client.table("parts_catalog").insert(payload).execute()
        inserted = result.data or []
        if not inserted:
            raise RuntimeError(f"Catalog insert returned no row for {product.part_number}")
        catalog_id = inserted[0]["catalog_id"]
        action = "inserted"

    aliases = {product.part_number}
    if product.barcode and product.barcode not in skipped_barcodes:
        aliases.add(product.barcode)
    for barcode in aliases:
        existing_alias = (
            client.table("part_catalog_barcodes")
            .select("barcode,catalog_id")
            .eq("barcode", barcode)
            .limit(1)
            .execute()
        )
        alias_payload = {
            "barcode": barcode,
            "catalog_id": catalog_id,
            "source": "manufacturer",
        }
        if existing_alias.data:
            alias_owner = existing_alias.data[0].get("catalog_id")
            if alias_owner != catalog_id:
                logger.warning(
                    "Barcode alias %s already belongs to catalog row %s; not reassigning to %s",
                    barcode,
                    alias_owner,
                    catalog_id,
                )
                continue
            client.table("part_catalog_barcodes").update(alias_payload).eq("barcode", barcode).execute()
        else:
            client.table("part_catalog_barcodes").insert(alias_payload).execute()
    return action


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=[*SOURCES, "all"], default="all")
    parser.add_argument("--limit", type=int, help="Maximum products per manufacturer")
    parser.add_argument("--delay", type=float, default=1.0, help="Seconds between product requests")
    parser.add_argument("--apply", action="store_true", help="Write results to parts_catalog")
    args = parser.parse_args()

    sources = list(SOURCES) if args.source == "all" else [args.source]
    counts = {"parsed": 0, "inserted": 0, "updated": 0}
    for source in sources:
        for product in fetch_products(source, limit=args.limit, delay=max(args.delay, 0)):
            counts["parsed"] += 1
            action = upsert_product(product) if args.apply else "dry-run"
            if action in counts:
                counts[action] += 1
            print(f"{action:8} {product.brand:14} {product.part_number:24} {product.barcode or '-'} {product.name}")
    print(json.dumps(counts, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
