"""Run only in the disposable database prepared by catalog_write_permissions.sql.

Requires psql and explicit FINDEZ_DISPOSABLE_SQL_TESTS=1, never production.
The CI PostgreSQL job and network-disabled local container use the same runner.
"""
import json
import os
import subprocess
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier


def sql(statement):
    result = subprocess.run(
        ['psql', '-X', '-Atq', '-v', 'ON_ERROR_STOP=1'],
        input=statement, capture_output=True, text=True, timeout=15, check=True,
    )
    return result.stdout.strip()


def together(statements):
    start = Barrier(len(statements))

    def execute(statement):
        start.wait(timeout=5)
        # Hold the barcode lock briefly so another real connection contends.
        output = sql('BEGIN; SET LOCAL ROLE service_role; ' + statement
                     + '; SELECT pg_sleep(0.05); COMMIT;')
        return output.splitlines()[0]

    with ThreadPoolExecutor(max_workers=len(statements)) as executor:
        return list(executor.map(execute, statements))


def main():
    if os.environ.get('FINDEZ_DISPOSABLE_SQL_TESTS') != '1':
        raise SystemExit('This runner requires an explicitly prepared disposable test database.')
    first, second = ('53000000-0000-4000-8000-000000000001',
                     '53000000-0000-4000-8000-000000000002')
    assert sql("SELECT count(*)=2 FROM public.parts_catalog WHERE "
               f"(catalog_id='{first}' AND canonical_name='Verified A') OR "
               f"(catalog_id='{second}' AND canonical_name='Verified B')") == 't'
    count_results = together([
        "SELECT public.findez_save_community_catalog('race-community','{\"name\":\"Race community\"}','user')"
    ] * 8)
    assert count_results == ['t'] * 8
    assert sql("SELECT confirmation_count FROM public.parts_catalog WHERE barcode='race-community'") == '8'

    for index in range(8):
        # UPC and zero-prefixed EAN target different verified owners.
        barcode = f'9999999999{index:02d}'
        results = together([
            f"SELECT public.findez_link_verified_barcode_alias('{barcode}','{first}')",
            f"SELECT public.findez_link_verified_barcode_alias('0{barcode}','{second}')",
        ])
        assert sorted(results) == ['f', 't'], results
        assert sql('SELECT count(DISTINCT catalog_id) FROM public.part_catalog_barcodes '
                   f"WHERE barcode IN ('{barcode}','0{barcode}')") == '1'

        # A community insert cannot race an alias into a different catalog row.
        barcode = f'8888888888{index:02d}'
        results = together([
            f"SELECT public.findez_save_community_catalog('{barcode}','{{\"name\":\"Race cache\"}}','user')",
            f"SELECT public.findez_link_verified_barcode_alias('0{barcode}','{first}')",
        ])
        assert sorted(results) == ['f', 't'], results
        assert sql('SELECT count(DISTINCT catalog_id) FROM ('
                   f"SELECT catalog_id FROM public.parts_catalog WHERE barcode IN ('{barcode}','0{barcode}') "
                   'UNION ALL SELECT catalog_id FROM public.part_catalog_barcodes '
                   f"WHERE barcode IN ('{barcode}','0{barcode}')) owners") == '1'
    print(json.dumps({'concurrent_community_writes': 8, 'confirmation_count': 8,
                      'equivalent_alias_races': 8, 'community_alias_races': 8,
                      'conflicting_owners': 0, 'passed': True}))


if __name__ == '__main__':
    main()
