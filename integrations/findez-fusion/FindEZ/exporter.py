"""Read-only Fusion adapter. No adsk import, network, credentials or design writes.

All API reads run synchronously on Fusion's command thread. Plain dictionaries
leave this boundary; tests use small protocol fakes, not a simulated CAD engine.
"""

import json
from uuid import uuid4

VERSION = '0.1.0'
MAX_BYTES = 5 * 1024 * 1024


def extract(design, host_version):
    warnings = []

    def warn(message):
        if message not in warnings:
            if len(warnings) >= 200:
                raise ValueError('Too many incomplete properties. Resolve references and retry.')
            warnings.append(message)

    def read(obj, name, default=None):
        try:
            return getattr(obj, name)
        except (AttributeError, RuntimeError):
            warn('Unavailable Fusion property: ' + name)
            return default

    def text(value, limit=512):
        value = str(value or '')
        if len(value) > limit:
            raise ValueError('A CAD property exceeds the supported export size.')
        return value

    def collection(values):
        if values is None:
            raise ValueError('An assembly reference could not be read. Resolve it and retry.')
        return [values.item(i) for i in range(values.count)]

    def file_identity(data_file, fallback):
        if not data_file:
            return fallback
        return (text(read(data_file, 'id', '')) or fallback[0],
                text(read(data_file, 'versionId', '')) or fallback[1])

    def attr(component, name):
        attributes = read(component, 'attributes')
        value = attributes.itemByName('FindEZ', name) if attributes else None
        return text(value.value) if value else ''

    document = design.parentDocument
    dirty = document.isModified
    session = str(uuid4())
    data_file = read(document, 'dataFile')
    source = file_identity(data_file, ('unsaved:' + session, 'session:' + session))
    config = ''
    if read(design, 'isConfiguredDesign', False):
        table = read(design, 'configurationTopTable')
        row = read(table, 'activeRow') if table else None
        config = text(read(row, 'name', '')) if row else ''
        if not config:
            raise ValueError('The active configuration could not be identified.')
        warn('Configured design: independently verify suppression and quantities before use.')
    definitions, occurrences, identities = [], [], {}

    def visit(component, children, parent_key, path, occurrence, inherited_source, inherited_config, depth):
        if depth > 64 or len(occurrences) >= 20000:
            raise ValueError('Assembly exceeds the prototype size or depth limit.')
        key = 'o' + str(len(occurrences))
        source_here = inherited_source
        configuration = inherited_config
        suppression = 'active'
        visible = None
        token = ''
        if occurrence is not None:
            token = text(read(occurrence, 'entityToken', ''), 4096)
            visible = read(occurrence, 'isVisible')
            timeline = read(occurrence, 'timelineObject')
            state = read(timeline, 'isSuppressed') if timeline else None
            suppression = 'unknown' if state is None else 'suppressed' if state else 'active'
            if suppression == 'unknown':
                warn('Suppression could not be established for ' + key + '.')
            reference = read(occurrence, 'documentReference')
            if reference:
                source_here = file_identity(read(reference, 'dataFile'), ('unresolved:' + key, 'unknown'))
                if source_here[0].startswith('unresolved:'):
                    suppression = 'unknown'
                    warn('An external reference could not be identified at ' + key + '.')
            config_row = read(occurrence, 'configurationRow')
            if config_row:
                configuration = text(read(config_row, 'name', ''))
                source_here = file_identity(read(occurrence, 'configuredDataFile'), source_here)
                warn('Configured occurrence: independently verify suppression and quantities before use.')
        name = text(read(component, 'name', 'Unnamed component'))
        part = text(read(component, 'partNumber', ''))
        policy = attr(component, 'procurement_policy')
        if policy and policy not in ('purchase', 'fabricate', 'assembly', 'exclude', 'review'):
            raise ValueError('FindEZ procurement_policy is invalid.')
        if not policy:
            policy = 'assembly' if children else 'purchase'
            bodies = read(component, 'bRepBodies')
            meshes = read(component, 'meshBodies')
            body_count = (bodies.count if bodies else 0) + (meshes.count if meshes else 0)
            if children and body_count:
                warn('Assembly ' + key + ' has its own bodies; they are not separate BOM parts. Review procurement policy.')
            if not children and not body_count:
                policy = 'review'
                warn('Leaf ' + key + ' has no readable bodies; review whether it is a required part.')
        comp_id = text(read(component, 'id', ''))
        # IDs persist within a design, but copies/revisions can share an ID.
        # Include source file/version/config and observed metadata. Never compare
        # entityToken strings to decide whether definitions are the same.
        manufacturer, barcode = attr(component, 'manufacturer'), attr(component, 'barcode')
        identity = (source_here, configuration, comp_id or key, name, part, policy, manufacturer, barcode)
        definition_key = identities.get(identity)
        if definition_key is None:
            if len(definitions) >= 5000:
                raise ValueError('Assembly exceeds the prototype definition limit.')
            definition_key = 'd' + str(len(definitions))
            identities[identity] = definition_key
            definitions.append({'key': definition_key, 'name': name, 'part_number': part,
                                'manufacturer': manufacturer, 'barcode': barcode,
                                'part_number_is_default': not part or part.strip().casefold() == name.strip().casefold(),
                                'procurement_policy': policy, 'source_token': text(read(component, 'entityToken', ''), 4096),
                                'source_document': source_here[0], 'source_version': source_here[1],
                                'configuration': configuration})
        occurrences.append({'key': key, 'definition_key': definition_key, 'parent_key': parent_key,
                            'source_path': text(path, 4096), 'source_token': token,
                            'suppression': suppression, 'visible': visible})
        for child in children:
            child_component = child.component
            if child_component is None:
                raise ValueError('An assembly component is unavailable. Resolve references and retry.')
            visit(child_component, collection(child.childOccurrences), key, child.fullPathName,
                  child, source_here, configuration, depth + 1)

    root = design.rootComponent
    visit(root, collection(root.occurrences), None, root.name, None, source, config, 0)
    if document.isModified != dirty:
        raise ValueError('The document changed during extraction. Export again.')
    snapshot = {'schema_version': 1, 'provider': 'fusion', 'extraction_id': session,
                'adapter_version': VERSION, 'host_version': text(host_version),
                'document': {'external_id': source[0], 'name': text(document.name)},
                'revision': {'kind': 'unsaved_session' if dirty or not data_file else 'saved_version',
                             'id': 'session:' + session if dirty or not data_file else source[1],
                             'dirty': dirty, 'configuration': config},
                'completeness': 'partial' if warnings else 'complete', 'warnings': warnings,
                'definitions': definitions, 'occurrences': occurrences}
    if len(json.dumps(snapshot).encode('utf-8')) > MAX_BYTES:
        raise ValueError('Export exceeds 5 MiB. Analyze a smaller assembly.')
    return snapshot
