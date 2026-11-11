"""Bounded Fusion snapshot contract and deterministic occurrence counting."""

from collections import Counter
from typing import Annotated, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StrictBool, model_validator

Text = Annotated[str, Field(max_length=512)]
Key = Annotated[str, Field(min_length=1, max_length=128, pattern=r'^[A-Za-z0-9_.:-]+$')]
MAX_SNAPSHOT_BYTES = 5 * 1024 * 1024


class Model(BaseModel):
    model_config = ConfigDict(extra='forbid')


class Document(Model):
    external_id: Text
    name: Text


class Revision(Model):
    kind: Literal['saved_version', 'unsaved_session']
    id: Text
    dirty: StrictBool
    configuration: Text


class Definition(Model):
    key: Key
    name: Text
    part_number: Text = ''
    manufacturer: Text = ''
    barcode: Text = ''
    part_number_is_default: StrictBool = True
    procurement_policy: Literal['purchase', 'fabricate', 'assembly', 'exclude', 'review']
    source_token: Annotated[str, Field(max_length=4096)] = ''
    source_document: Text = ''
    source_version: Text = ''
    configuration: Text = ''


class Occurrence(Model):
    key: Key
    definition_key: Key
    parent_key: Key | None
    source_path: Annotated[str, Field(max_length=4096)]
    source_token: Annotated[str, Field(max_length=4096)] = ''
    suppression: Literal['active', 'suppressed', 'unknown']
    visible: StrictBool | None = None


class Snapshot(Model):
    schema_version: Literal[1]
    provider: Literal['fusion']
    extraction_id: UUID
    adapter_version: Text
    host_version: Text
    document: Document
    revision: Revision
    completeness: Literal['complete', 'partial']
    warnings: list[Annotated[str, Field(max_length=2000)]] = Field(max_length=200)
    definitions: list[Definition] = Field(min_length=1, max_length=5000)
    occurrences: list[Occurrence] = Field(min_length=1, max_length=20000)

    @model_validator(mode='after')
    def validate_graph(self):
        definitions = {d.key: d for d in self.definitions}
        if len(definitions) != len(self.definitions):
            raise ValueError('Duplicate definition key.')
        depths = {}
        roots = 0
        used = set()
        for occurrence in self.occurrences:
            if occurrence.key in depths or occurrence.definition_key not in definitions:
                raise ValueError('Duplicate occurrence or missing definition.')
            if occurrence.parent_key is None:
                roots += 1
                depth = 0
            else:
                if occurrence.parent_key not in depths:
                    raise ValueError('Parents must precede children; cycles are not allowed.')
                depth = depths[occurrence.parent_key] + 1
            if depth > 64:
                raise ValueError('Assembly exceeds supported depth.')
            depths[occurrence.key] = depth
            used.add(occurrence.definition_key)
        if roots != 1 or used != set(definitions):
            raise ValueError('Use one root and no orphan definitions.')
        if self.revision.dirty and self.revision.kind != 'unsaved_session':
            raise ValueError('Unsaved changes require a session revision.')
        return self


def requirements(snapshot: Snapshot) -> tuple[list[dict], list[str]]:
    """Walk each contextual placement once. Never sum flattened and nested trees."""
    definitions = {d.key: d for d in snapshot.definitions}
    children = Counter(o.parent_key for o in snapshot.occurrences if o.parent_key)
    blocked = {}
    counts = Counter()
    unknown = set()
    warnings = list(snapshot.warnings)
    for occurrence in snapshot.occurrences:
        definition = definitions[occurrence.definition_key]
        parent_blocked = blocked.get(occurrence.parent_key, False)
        excluded = parent_blocked or occurrence.suppression == 'suppressed' or definition.procurement_policy == 'exclude'
        uncertain = occurrence.suppression == 'unknown'
        if uncertain and not excluded:
            warnings.append('Suppression is unknown at ' + occurrence.key + '; its subtree is not counted.')
        blocked[occurrence.key] = excluded or uncertain
        if blocked[occurrence.key]:
            continue
        policy = definition.procurement_policy
        if policy == 'assembly':
            if not children[occurrence.key]:
                warnings.append('Empty assembly ' + occurrence.key + ' needs review.')
            continue
        # A purchased/fabricated/reviewed assembly is one procurement unit; keep
        # descendant source nodes but never count their parts a second time.
        blocked[occurrence.key] = True
        counts[definition.key] += 1
        if policy == 'review':
            unknown.add(definition.key)
    rows = []
    for key, quantity in counts.items():
        definition = definitions[key]
        rows.append({**definition.model_dump(), 'required': quantity, 'unit': 'each',
                     'needs_review': key in unknown})
    return rows, list(dict.fromkeys(warnings))
