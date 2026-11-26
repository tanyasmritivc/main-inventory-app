import io
import json
import os
import subprocess
import zipfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from uuid import uuid4

import pytest
from fastapi import HTTPException

from app.services.commerce import supplier_orders as orders


def archive(name, content):
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, "w") as out:
        out.writestr(name, content)
    return stream.getvalue()


CSV = b"Order Number,SKU,Product Name,Qty,Pack Size,Status\nG-42,S-12,M4 x 12 screws,2,50,delivered\n"


def test_reviewed_units_and_identity():
    source = orders.preview(CSV, "orders.csv")
    (line,) = orders.reviewed(source["rows"], source)
    assert (
        line["order"],
        line["line"],
        line["quantity"],
        line["pack"],
        line["status"],
    ) == ("G-42", "S-12", 2, 50, "delivered")
    for changed in [{"pack": ""}, {"pack": -1}, {"source_row": 40}, {"quantity": 2.7}]:
        with pytest.raises(HTTPException):
            orders.reviewed([{**line, **changed}], source)
    with pytest.raises(HTTPException):
        orders.reviewed([line, line], source)


@pytest.mark.parametrize(
    "name,data",
    [
        ("bad.zip", b"bad"),
        ("path.zip", archive("../a.csv", CSV)),
        ("huge.zip", archive("a.csv", b"x" * (orders.MAX_BYTES + 1))),
        ("binary.csv", b"\x00abc"),
        ("wrong.pdf", b"fake"),
    ],
)
def test_unsafe_or_unsupported_files(name, data):
    with pytest.raises(HTTPException):
        orders.preview(data, name)


def test_excel_header_offsets_duplicate_labels_and_distinct_sheets():
    from openpyxl import Workbook

    book = Workbook()
    sheet = book.active
    sheet.title = "Fasteners"
    sheet.append(["goBILDA packing slip"])
    sheet.append(
        ["Order #", "Article", "Qty", "Qty", "SKU", "Units per pack", "", "Extra"]
    )
    sheet.append(["0091", "M4 screws", 2, 8, 12, 50, "left", "custom info"])
    sheet["E3"].number_format = "0000"
    other = book.create_sheet("Shipping")
    other.append(["Code", "Tracking"])
    other.append(["UPS", "123"])
    out = io.BytesIO()
    book.save(out)
    data = out.getvalue()
    source = orders.preview(data, "parts.xlsx")
    first, second = source["tables"]
    assert (
        first["header"] == 2
        and "quantity" not in first["suggestions"]
        and "name" not in first["suggestions"]
    )
    assert second["sheet"] == "Shipping"
    cfg = [
        {
            "header": 2,
            "mapping": {"name": 1, "quantity": 2, "sku": 4, "order": 0, "pack": 5},
        },
        None,
    ]
    mapped = orders.preview(data, "parts.xlsx", cfg)
    (line,) = orders.reviewed(mapped["rows"], mapped)
    assert (line["order"], line["quantity"], line["pack"], line["sku"]) == (
        "0091",
        2,
        50,
        "0012",
    )
    assert line["original"]["cells"][3:] == ["8", "0012", "50", "left", "custom info"]
    assert (
        line["original"]["headers"][2:4] == ["Qty", "Qty"] and line["source_row"] == 3
    )
    with pytest.raises(HTTPException):
        orders.preview(
            data,
            "parts.xlsx",
            [{"header": 2, "mapping": {"name": 1, "quantity": 1}}, None],
        )


def test_possible_shipped_quantity_is_not_guessed_as_ordered():
    from app.services.commerce.order_tables import suggest

    assert "quantity" not in suggest(["SKU", "Qty", "Qty Shipped", "Price"])
    assert suggest(["SKU", "Qty Ordered", "Qty Shipped"])["quantity"] == 1


@pytest.mark.parametrize(
    "name,data",
    [
        ("screen.png", b"image"),
        ("purchase.zip", archive("valid.csv", CSV)),
        ("order.XLS", CSV),
        ("spreadsheet.tsv", CSV),
        ("renamed.xlsx", archive("order.csv", CSV)),
        ("renamed.csv", b"\x89PNG\r\n\x1a\n"),
        ("order.pdf", b"%PDF-1.7"),
        ("noext", CSV),
        ("empty.csv", b""),
        ("oversize.csv", b"x" * (orders.MAX_BYTES + 1)),
        ("bad.json", b'{"sku":"s"}'),
    ],
)
def test_only_spreadsheets_can_be_imported(name, data):
    with pytest.raises(HTTPException):
        orders.preview(data, name)
    with pytest.raises(HTTPException):
        orders.preview(data, name, pasted={name: "Name,Quantity\nScrew,2"})


@pytest.mark.parametrize(
    "name,data",
    [
        ("vendor.CSV", b"SKU;Qty;Order Number\n0012;3;42"),
        ("vendor.JSON", b'{"items":[{"SKU":"0012","Qty":3,"Order Number":"42"}]}'),
        ("parts.json", b'[{"SKU":"0012","Qty":3,"Order Number":"42"}]'),
    ],
)
def test_spreadsheet_formats(name, data):
    (row,) = orders.preview(data, name)["rows"]
    assert (row["sku"], row["quantity"], row["order"], row["pack"]) == (
        "0012",
        "3",
        "42",
        "",
    )


def test_http_review_rechecks_file_and_keeps_original_column_assignment(monkeypatch):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from app.api.routes import supplier_orders as api
    from app.core.auth import AuthenticatedUser, get_current_user

    app = FastAPI()
    app.include_router(api.router)
    app.dependency_overrides[get_current_user] = lambda: AuthenticatedUser("admin")
    monkeypatch.setattr(api, "authorize_scope", lambda *args: None)
    saved = []
    monkeypatch.setattr(
        orders,
        "rpc",
        lambda actor, org, action, payload: saved.append(payload) or {"created": 1},
    )
    path = "/organizations/" + str(uuid4()) + "/orders"
    client = TestClient(app)
    blob = {"file": ("order.csv", CSV, "text/csv")}
    image = {"file": ("screen.png", b"image", "text/csv")}
    assert client.post(path + "/preview", files=image).status_code == 422
    assert (
        client.post(
            path + "/import",
            files=image,
            data={
                "supplier": "test",
                "historical": "true",
                "assignments": "[]",
                "rows": "[]",
                "digest": "0" * 64,
            },
        ).status_code
        == 422
    )
    assert not saved
    result = client.post(path + "/preview", files=blob)
    assert result.status_code == 200, result.text
    preview = result.json()
    fields = {
        "supplier": "goBILDA",
        "historical": "false",
        "digest": preview["digest"],
        "assignments": json.dumps(preview["assignments"]),
        "rows": json.dumps(preview["rows"]),
    }
    assert (
        client.post(
            path + "/import", files=blob, data={**fields, "digest": "0" * 64}
        ).status_code
        == 422
    )
    assert client.post(path + "/import", files=blob, data=fields).status_code == 200
    space = str(uuid4())
    scoped = client.post(path + "/preview", files=blob, data={"space_id": space})
    assert scoped.status_code == 200 and "space_review" in scoped.json()
    assert saved[-1]["space_id"] == space and saved[-1]["rows"][0]["sku"] == "S-12"
    assert (
        client.post(
            path + "/import", files=blob, data={**fields, "space_id": space}
        ).status_code
        == 200
    )
    assert saved[-1]["space_id"] == space
    assert saved[0]["rows"][0]["original"]["cells"] == [
        "G-42",
        "S-12",
        "M4 x 12 screws",
        "2",
        "50",
        "delivered",
    ]


# Supply an empty, disposable local PostgreSQL database with the usual Supabase roles.
@pytest.fixture
def db():
    database = os.environ.get("FINDEZ_ORDER_TEST_DB", "")
    if not database:
        pytest.skip(
            "Set FINDEZ_ORDER_TEST_DB to a new local supplier_orders_test_* database."
        )
    assert database.startswith("supplier_orders_test_") and os.environ.get(
        "PGHOST", ""
    ).startswith(("/", "127.0.0.1", "localhost"))

    def sql(statement, ok=True):
        proc = subprocess.run(
            ["psql", "-X", "-A", "-t", "-q", "-v", "ON_ERROR_STOP=1", "-d", database],
            input=statement,
            text=True,
            capture_output=True,
        )
        if ok:
            assert proc.returncode == 0, proc.stderr
        else:
            assert proc.returncode != 0
        return proc.stdout.strip()

    sql(
        """CREATE TABLE app_organizations(organization_id uuid primary key);
    CREATE TABLE app_organization_members(organization_id uuid,user_id uuid,role text);
    CREATE TABLE app_inventories(inventory_id uuid primary key, organization_id uuid,name text);
    CREATE TABLE test_inventory_grants(inventory_id uuid,user_id uuid,role text);
    CREATE FUNCTION findez_inventory_role(uuid,uuid) RETURNS text LANGUAGE sql AS
      'SELECT role FROM test_inventory_grants WHERE inventory_id=$1 AND user_id=$2';
    CREATE TABLE spaces(id uuid primary key,inventory_id uuid,name text);
    CREATE TABLE bins(id uuid primary key,space_id uuid,name text);
    CREATE TABLE items(item_id uuid primary key,inventory_id uuid,user_id uuid,name text,part_number text,quantity integer,location text,space_id uuid,bin_id uuid);
    CREATE TABLE item_events(item_id uuid,user_id uuid,inventory_id uuid,event_type text,content text,quantity_delta integer);"""
    )
    sql(
        (
            Path(__file__).resolve().parents[1]
            / "supabase/migrations/20261124_supplier_orders.sql"
        ).read_text()
    )
    sql(
        (
            Path(__file__).resolve().parents[1]
            / "supabase/migrations/20261125_space_supplier_orders.sql"
        ).read_text()
    )
    return sql


def test_database_receiving_retries_isolation_and_cad(db):
    org, other, admin, viewer, inv, item, variant, foreign_space = [
        str(uuid4()) for _ in range(8)
    ]
    db(f"""INSERT INTO app_organizations VALUES ('{org}'),('{other}');
    INSERT INTO app_organization_members VALUES ('{org}','{admin}','owner'),('{org}','{viewer}','member');
    INSERT INTO app_inventories VALUES ('{inv}','{org}','Fasteners'),('{foreign_space}','{other}','Private');
    INSERT INTO test_inventory_grants VALUES ('{inv}','{admin}','owner'),('{foreign_space}','{admin}','owner');
    INSERT INTO items VALUES ('{item}','{inv}','{admin}','M4 x 12 screws','S-12',40,'A1'),
      ('{variant}','{inv}','{admin}','M4 x 20 screws','S-20',9,'A2');""")

    shelf = str(uuid4())
    db(
        f"insert into spaces values ('{shelf}','{inv}','Fastener Shelf'); update items set space_id='{shelf}' where item_id='{item}'"
    )

    def rpc(action, payload, who=admin, scope=org, ok=True):
        payload = json.dumps(payload).replace("'", "''")
        value = db(
            f"select findez_supplier_orders('{who}','{scope}','{action}','{payload}');",
            ok,
        )
        return json.loads(value) if ok else None

    source = orders.preview(CSV, "order.csv")
    payload = {
        **source,
        "rows": orders.reviewed(source["rows"], source),
        "supplier": "goBILDA",
        "historical": False,
        "content": "eA==",
    }
    assert rpc("import", payload)["created"] == 1
    assert rpc("import", payload)["duplicate"]
    rpc("import", {**payload, "supplier": "Unrelated supplier"}, ok=False)
    assert rpc("import", {**payload, "digest": "alternate-document"})["created"] == 0
    rpc(
        "import",
        {**payload, "digest": "conflict", "rows": [{**payload["rows"][0], "pack": 75}]},
        ok=False,
    )

    def search(query):
        return rpc("search", {"query": query})

    found = search("S-12")
    (line,) = found["order_lines"]
    assert (line["ordered"], line["received"], line["outstanding"]) == (100, 0, 100)
    assert found["recorded_inventory"][0]["recorded_quantity"] == 40
    assert found["recorded_inventory"][0]["space_name"] == "Fastener Shelf"
    assert len(search("M4")["recorded_inventory"]) == 2
    receipt = {
        "request_id": str(uuid4()),
        "action": "receive",
        "line_id": line["id"],
        "inventory_id": inv,
        "item_id": item,
        "quantity": 25,
    }
    with ThreadPoolExecutor(2) as pool:
        results = list(pool.map(lambda _: rpc("receipt", receipt), range(2)))
    assert results[0] == results[1]
    found = search("S-12")
    assert found["recorded_inventory"][0]["recorded_quantity"] == 65
    assert (
        found["order_lines"][0]["received"],
        found["order_lines"][0]["outstanding"],
    ) == (25, 75)
    assert found["order_lines"][0]["recent_receipts"][0]["quantity"] == 25
    assert db("select count(*) from item_events") == "1"
    cad = json.loads(
        db(f"select findez_supplier_bom_orders('{admin}','{inv}',array['s-12']);")
    )
    assert len(cad) == 1 and cad[0]["outstanding"] == 75
    rpc("receipt", {**receipt, "quantity": 26}, ok=False)
    rpc("receipt", {**receipt, "request_id": str(uuid4()), "quantity": 76}, ok=False)
    rpc(
        "receipt",
        {**receipt, "inventory_id": foreign_space, "request_id": str(uuid4())},
        ok=False,
    )
    rpc("receipt", receipt, who=viewer, ok=False)
    rpc("search", {}, scope=other, ok=False)
    member = rpc("search", {"query": "S-12"}, who=viewer)
    assert (
        not member["recorded_inventory"]
        and not member["order_lines"][0]["recent_receipts"]
    )
    rpc("source", {"id": line["source_id"]}, who=viewer, ok=False)
    assert rpc("source", {"id": line["source_id"]})["content"] == "eA=="
    fields = rpc("fields", {"id": line["id"]})
    assert (
        fields["original"]["headers"][1] == "SKU"
        and fields["original"]["cells"][1] == "S-12"
    )
    rpc("fields", {"id": line["id"]}, who=viewer, ok=False)
    rpc(
        "receipt",
        {
            **receipt,
            "action": "already_counted",
            "quantity": 10,
            "request_id": str(uuid4()),
        },
    )
    assert search("S-12")["recorded_inventory"][0]["recorded_quantity"] == 65
    rpc(
        "receipt",
        {
            **receipt,
            "action": "cancel",
            "inventory_id": None,
            "item_id": None,
            "quantity": 65,
            "request_id": str(uuid4()),
        },
    )
    assert search("S-12")["order_lines"][0]["outstanding"] == 0
    assert (
        db(
            "SELECT has_function_privilege('authenticated','findez_supplier_orders(uuid,uuid,text,jsonb)','execute')"
        )
        == "f"
    )
    scoped_row = {**payload["rows"][0], "order": "SPACE-100"}
    scoped = {
        **payload,
        "space_id": shelf,
        "digest": "space-upload",
        "rows": [scoped_row],
    }
    check = rpc("preview", scoped)
    assert not check["duplicate"] and [m["item_id"] for m in check["matches"]] == [item]
    assert check["matches"][0]["recorded_quantity"] == 65
    assert rpc("import", scoped)["created"] == 1
    assert rpc("preview", scoped)["duplicate"]
    assert rpc("import", scoped)["duplicate"]
    scoped_result = rpc("search", {"space_id": shelf, "query": "M4×12"})
    assert [l["order_number"] for l in scoped_result["order_lines"]] == ["SPACE-100"]
    assert scoped_result["recorded_inventory"][0]["recorded_quantity"] == 65
    scoped_line = scoped_result["order_lines"][0]

    def space_summary(who):
        return json.loads(
            db(f"select findez_space_order_summary('{who}','{inv}','{shelf}');")
        )

    assert space_summary(admin)["lines"][0]["ordered"] == 100
    assert space_summary(viewer)["lines"] == []
    assert scoped_line["order_space_name"] == "Fastener Shelf"
    assert len(search("M4 x 12")["order_lines"]) == 2
    assert not search("M4 x 120")["order_lines"]
    assert not rpc("search", {"query": "SPACE-100"}, who=viewer)["order_lines"]
    rpc("search", {"space_id": shelf}, who=viewer, ok=False)
    rpc("import", {**scoped, "space_id": str(uuid4())}, ok=False)
    assert rpc("search", {}, who=admin)["space_orders_supported"]
    for status, historical in [
        ("returned", False),
        ("cancelled", False),
        ("delivered", True),
    ]:
        row = {**payload["rows"][0], "status": status, "order": status}
        rpc(
            "import",
            {**payload, "rows": [row], "historical": historical, "digest": status},
        )
        closed = search(status)["order_lines"][0]
        assert closed["outstanding"] is None
        rpc(
            "receipt",
            {**receipt, "line_id": closed["id"], "request_id": str(uuid4())},
            ok=False,
        )
