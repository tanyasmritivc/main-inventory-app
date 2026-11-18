"""Real product references only. No generated images or category fallback."""
from urllib.parse import urlsplit
from app.services.catalog_service import barcode_candidates, _normalized_brand
from app.services.supabase_client import get_supabase_raw


def public_https(value):
    import ipaddress
    if not isinstance(value, str) or len(value) > 2000:
        return False
    try:
        parsed = urlsplit(value)
        port = parsed.port
        host = parsed.hostname or ''
    except ValueError:
        return False
    if parsed.scheme != 'https' or parsed.username or parsed.password or port not in (None, 443):
        return False
    if '.' not in host or host.endswith(('.local', '.internal', '.localhost')):
        return False
    try:
        return ipaddress.ip_address(host).is_global
    except ValueError:
        return True


def product_evidence(item):
    """Read named identifiers from original columns without guessing from prose."""
    result = dict(item)
    import re
    aliases = {'barcode': {'barcode','upc','ean','gtin'}, 'brand': {'brand','manufacturer'},
               'part_number': {'partnumber','manufacturerpartnumber','mpn','modelnumber'}}
    fields = (item.get('import_data') or {}).get('fields') or []
    for key, names in aliases.items():
        if str(result.get(key) or '').strip(): continue
        values = {str(field.get('value') or '').strip() for field in fields
                  if re.sub(r'[^a-z0-9]', '', str(field.get('name') or '').lower()) in names}
        values.discard('')
        if len(values) == 1: result[key] = values.pop()
    return result


async def suggest(item):
    item = product_evidence(item)
    db = get_supabase_raw()
    barcode = str(item.get('barcode') or '').strip()
    brand, part = str(item.get('brand') or ''), str(item.get('part_number') or '').strip()
    query = db.table('parts_catalog').select('*').eq('verification_status', 'verified')
    basis = 'exact_name'
    if barcode:
        query = query.in_('barcode', barcode_candidates(barcode)); basis = 'barcode'
    elif brand and part:
        query = query.eq('part_number', part); basis = 'brand_and_part_number'
    else:
        name = str(item.get('name') or '').strip()
        if not name:
            return {'reason': 'Add a product name, barcode or manufacturer part number.'}
        query = query.eq('canonical_name', name)
    candidates = query.limit(3).execute().data or []
    if basis == 'brand_and_part_number':
        candidates = [r for r in candidates if _normalized_brand(r.get('brand')) == _normalized_brand(brand)]
    if len(candidates) == 1:
        row = candidates[0]
        if brand and row.get('brand') and _normalized_brand(brand) != _normalized_brand(row['brand']):
            return {'reason': 'The product reference has a conflicting brand. Check the exact identifier.'}
        if basis == 'exact_name':
            # A unique category label is not evidence of an exact product.
            name = str(item.get('name') or '').casefold()
            model = str(row.get('part_number') or '').strip().casefold()
            maker = str(row.get('brand') or '').strip().casefold()
            if not model or not maker or model not in name or maker not in name:
                return {'reason': 'The name does not identify an exact model. Add a barcode or manufacturer and part number.'}
        source = row.get('product_url') or row.get('source_url')
        image = row.get('image_url')
        if public_https(image) and public_https(source):
            return {'image_url': image, 'source_url': source, 'product_name': row.get('canonical_name'),
                    'identity': {'barcode': barcode or None, 'brand': row.get('brand'), 'part_number': row.get('part_number')},
                    'match_basis': basis, 'confidence': 'high' if basis != 'exact_name' else 'medium',
                    'reason': 'Verified catalog product reference. Confirm the model and variant before approving.',
                    'real_product_photo': True}
    if barcode and barcode.isascii() and barcode.isdigit() and len(barcode) in (8, 12, 13, 14):
        # Reuse the configured existing product provider. It receives only the
        # barcode, never private notes or spreadsheet rows.
        from app.api.routes.items import lookup_go_upc
        row = await lookup_go_upc(barcode)
        if row and row.get('barcode') in barcode_candidates(barcode) and public_https(row.get('image_url')):
            if brand and row.get('brand') and _normalized_brand(brand) != _normalized_brand(row['brand']):
                return {'reason': 'The product provider returned a conflicting brand. Add or check the exact model.'}
            return {'image_url': row['image_url'], 'source_url': f'https://go-upc.com/search?q={barcode}',
                    'product_name': row.get('name'), 'identity': {'barcode': barcode, 'brand': row.get('brand')},
                    'match_basis': 'barcode', 'confidence': 'medium',
                    'reason': 'Barcode provider match. Confirm the model and variant before approving.', 'real_product_photo': True}
    return {'reason': 'No unique real product photo found. Add a barcode or manufacturer part number, or upload your own photo.'}
