"""Reviewed supplier documents. Quantities in purchase records are never stock."""

import csv
import json
import os
import subprocess
import sys
import hashlib
import io
import zipfile
from pathlib import Path, PurePosixPath
from typing import Literal
from uuid import UUID

from fastapi import HTTPException
from postgrest.exceptions import APIError
from pydantic import BaseModel, ConfigDict, Field, ValidationError, model_validator

from app.services.supabase_client import get_supabase_raw

from .order_tables import MAX_BYTES, MAX_ROWS, check_mapping, map_rows, read_tables


class Line(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra="forbid")
    order: str = Field(min_length=1, max_length=120)
    line: str = Field(min_length=1, max_length=120)
    sku: str = Field(default="", max_length=120)
    name: str = Field(min_length=1, max_length=300)
    quantity: int = Field(ge=1, le=1000000)
    pack: int = Field(ge=1, le=1000000)
    status: Literal[
        "unknown", "ordered", "shipped", "delivered", "cancelled", "returned"
    ] = "unknown"
    source_file: str = Field(max_length=240)
    source_sheet: str = Field(default="", max_length=160)
    source_row: int = Field(ge=1)

    @model_validator(mode="after")
    def bounded_units(self):
        if self.quantity * self.pack > 1000000000:
            raise ValueError("Ordered unit count exceeds the supported range.")
        return self


class Receipt(BaseModel):
    model_config = ConfigDict(extra="forbid")
    request_id: UUID
    quantity: int = Field(ge=1, le=1000000000)
    action: Literal["receive", "already_counted", "cancel"]
    inventory_id: UUID | None = None
    item_id: UUID | None = None
    space_id: UUID | None = None

    @model_validator(mode="after")
    def destination(self):
        required = self.action != "cancel"
        if (
            (not required and self.space_id is not None)
            or required != (self.item_id is not None)
            or required != (self.inventory_id is not None)
        ):
            raise ValueError(
                "Choose a destination item for each receipt or reconciliation."
            )
        return self


def preview(data, filename, assignments=None, pasted=None):
    if not data or len(data) > MAX_BYTES:
        raise HTTPException(413, "Choose a nonempty file up to 4 MB.")
    name = PurePosixPath(filename or "order").name[:240]
    tables, documents = [], []
    pasted = pasted or {}
    if (
        not isinstance(pasted, dict)
        or any(not isinstance(v, str) for v in pasted.values())
        or sum(len(v) for v in pasted.values()) > 500000
    ):
        raise HTTPException(422, "Paste a smaller table from the source document.")

    def add(content, member):
        result = read_tables(content, member)
        if result:
            tables.extend(result)
        else:
            documents.append(member)
            if pasted.get(member, "").strip():
                transcription = read_tables(
                    pasted[member].encode("utf-8"), "transcription.tsv"
                )
                for t in transcription:
                    t.update(file=member, sheet="Manually pasted table")
                tables.extend(transcription)

    try:
        if name.lower().endswith(".zip"):
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                entries = archive.infolist()
                if len(entries) > 32 or sum(m.file_size for m in entries) > MAX_BYTES:
                    raise HTTPException(413, "This order archive is too large.")
                seen = set()
                for member in entries:
                    path = PurePosixPath(member.filename)
                    if (
                        path.is_absolute()
                        or ".." in path.parts
                        or chr(92) in member.filename
                        or len(member.filename) > 240
                        or member.filename in seen
                    ):
                        raise HTTPException(
                            422, "Unsafe or duplicate archive member name."
                        )
                    seen.add(member.filename)
                    if (
                        member.is_dir()
                        or "__MACOSX" in path.parts
                        or path.name == ".DS_Store"
                    ):
                        continue
                    add(archive.read(member), member.filename)
        else:
            add(data, name)
        if set(pasted) - set(documents):
            raise ValueError("A pasted table must refer to an attached document.")
        if len(tables) > 32 or sum(len(t["records"]) for t in tables) > MAX_ROWS + 32:
            raise HTTPException(
                413, "Import up to 500 order lines and 32 sheets at a time."
            )
        if not tables and not documents:
            raise HTTPException(422, "The archive contains no source documents.")
        if assignments is None:
            assignments = [
                {"header": t["header"], "mapping": t["suggestions"]} for t in tables
            ]
        if not isinstance(assignments, list) or len(assignments) != len(tables):
            raise ValueError("Review the column mapping for each sheet.")
        rows = []
        for t, cfg in zip(tables, assignments):
            if cfg is None:
                continue
            if (
                not isinstance(cfg, dict)
                or not isinstance(cfg.get("mapping"), dict)
                or type(cfg.get("header")) is not int
            ):
                raise ValueError(
                    "Choose a header row and source columns for each included sheet."
                )
            rows.extend(map_rows(t, cfg["header"], cfg["mapping"]))
    except (
        zipfile.BadZipFile,
        RuntimeError,
        NotImplementedError,
        OSError,
        csv.Error,
        UnicodeError,
    ):
        raise HTTPException(
            422,
            "This file could not be opened. Check its encoding, format or encryption.",
        ) from None
    except ValueError as exc:
        raise HTTPException(422, str(exc)) from None
    return {
        "digest": hashlib.sha256(data).hexdigest(),
        "filename": name,
        "rows": rows,
        "tables": tables,
        "assignments": assignments,
        "documents": documents,
    }


def isolated_preview(data, filename, assignments=None, pasted=None):
    """Bound hostile workbook/PDF resource use outside the API process."""
    import base64

    if not data or len(data) > MAX_BYTES:
        raise HTTPException(413, "Choose a nonempty file up to 4 MB.")
    env = {
        "PATH": os.defpath,
        "PYTHONPATH": os.pathsep.join(str(p) for p in sys.path if p),
    }
    request = {
        "data": base64.b64encode(data).decode("ascii"),
        "filename": filename,
        "assignments": assignments,
        "pasted": pasted,
    }
    try:
        child = subprocess.run(
            [sys.executable, "-m", "app.services.commerce.order_reader"],
            input=json.dumps(request).encode(),
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=18,
            cwd=Path(__file__).resolve().parents[3],
            env=env,
        )
        if child.returncode == 0:
            response = json.loads(child.stdout)
            if "result" in response:
                return response["result"]
            raise HTTPException(response["status"], response["detail"])
    except (subprocess.TimeoutExpired, ValueError):
        pass
    raise HTTPException(
        422, "This document could not be read within the supported limits."
    )


def reviewed(rows, source):
    if not 1 <= len(rows) <= MAX_ROWS:
        raise HTTPException(422, "Review between 1 and 500 order lines.")
    allowed = {}
    for t, cfg in zip(source["tables"], source["assignments"]):
        if cfg is None:
            continue
        headers = check_mapping(t, cfg["header"], cfg["mapping"])
        for record in t["records"]:
            if record["number"] > cfg["header"]:
                allowed[(t["file"], t["sheet"], record["number"])] = {
                    "headers": headers,
                    "cells": record["cells"],
                    "mapping": cfg["mapping"],
                    "header_row": cfg["header"],
                }
    seen, positions = {}, set()
    clean = []
    for raw in rows:
        try:
            row = Line.model_validate(raw)
        except ValidationError:
            raise HTTPException(
                422,
                "Check every order number, line ID, description, status, quantity and units per pack.",
            ) from None
        pos = (row.source_file, row.source_sheet, row.source_row)
        if pos not in allowed and (
            row.source_file not in source["documents"] or row.source_sheet
        ):
            raise HTTPException(
                422, "Select a row or attached document included in the review."
            )
        key = (row.order, row.line)
        if pos in positions:
            raise HTTPException(422, "The same source row was selected twice.")
        positions.add(pos)
        record = {**row.model_dump(), "original": allowed.get(pos)}
        if key in seen:
            previous = seen[key]
            if previous["source_file"] == row.source_file or any(
                previous[k] != record[k]
                for k in ("sku", "name", "quantity", "pack", "status")
            ):
                raise HTTPException(
                    422,
                    "Order lines share an identity. Exclude duplicate evidence or supply the distinct vendor line IDs.",
                )
            previous.setdefault("supporting_sources", []).append(
                {
                    k: record[k]
                    for k in ("source_file", "source_sheet", "source_row", "original")
                }
            )
        else:
            seen[key] = record
            clean.append(record)
    return clean


def rpc(actor, org, action, data):
    try:
        return (
            get_supabase_raw()
            .rpc(
                "findez_supplier_orders",
                {
                    "p_actor": str(actor),
                    "p_org": str(org),
                    "p_action": action,
                    "p_data": data,
                },
            )
            .execute()
            .data
        )
    except APIError as exc:
        errors = {
            "42501": (403, "Access to these orders or the selected Space is required."),
            "P0002": (404, "The order line or destination could not be found."),
            "40001": (
                409,
                "The order or receipt conflicts with an existing record. Refresh before retrying.",
            ),
            "23514": (
                422,
                "Check the remaining order quantity and the selected inventory record.",
            ),
        }
        status, message = errors.get(
            exc.code, (503, "Order storage is unavailable. Please retry.")
        )
        raise HTTPException(status, message) from None


class EvidenceQuery(BaseModel):
    query: str = Field(default="", max_length=200)
    offset: int = Field(default=0, ge=0, le=1000000)


def evidence(actor, world, query="", offset=0, space_id=None):
    if world == "personal":
        return {"scope": "organization_orders_only"}
    return rpc(
        actor,
        world,
        "search",
        {
            "query": query,
            "offset": offset,
            "space_id": str(space_id) if space_id else None,
        },
    )
