"""Browse native Fusion models on the main thread, without filesystem downloads.

HTML receives short opaque IDs, never file paths or executable model URLs. Each
selection is bound to the active design and part until the picker is replaced.
"""
from uuid import uuid4
import adsk.fusion

PAGE = 40


class ModelBrowser:
    def __init__(self):
        self.clear()

    def clear(self):
        self.design = None
        self.part_id = None
        self.inventory_id = None
        self.models = {}
        self.folders = {}
        self.parents = {}

    def bind(self, app, part, inventory_id):
        design = adsk.fusion.Design.cast(app.activeProduct)
        if not design:
            raise ValueError('Open a Fusion design first.')
        part_id = str(part.get('item_id') or part.get('catalog_id'))
        if design != self.design or part_id != self.part_id or inventory_id != self.inventory_id:
            self.clear()
            self.design, self.part_id, self.inventory_id = design, part_id, inventory_id
        return design

    def _model(self, value, kind, name, linked=False, version=None):
        key = uuid4().hex
        self.models[key] = (kind, value)
        return {'id': key, 'name': str(name), 'linked': linked, 'version': version,
                'source': 'Current design' if kind == 'component' else 'Fusion project',
                'quality': 'user_selected_unverified'}

    def _folder(self, folder, parent):
        key = uuid4().hex
        self.folders[key] = folder
        self.parents[key] = parent
        return {'id': key, 'name': str(folder.name)}

    def browse(self, app, part, inventory_id, mode='design', folder_id=None, offset=0):
        design = self.bind(app, part, inventory_id)
        if type(offset) is not int or offset < 0 or offset > 50000 or mode not in ('design', 'project'):
            raise ValueError('Choose a model page from the panel.')
        self.models.clear()  # A stale rendered model cannot be inserted.
        rows, folders, parent, label, note = [], [], None, 'Current design', ''
        if mode == 'design':
            components = design.allComponents
            if components.count > 5000:
                raise ValueError('This design is too large for the model picker. Use a smaller assembly.')
            candidates = []
            for i in range(components.count):
                component = components.item(i)
                if component == design.rootComponent:
                    continue
                def attr(name):
                    value = component.attributes.itemByName('FindEZ', name)
                    return value.value if value else ''
                linked = ((part.get('item_id') and attr('inventory_item_id') == str(part['item_id'])
                           and attr('inventory_id') == inventory_id)
                          or (part.get('catalog_id') and attr('catalog_id') == str(part['catalog_id'])))
                candidates.append((bool(linked), component))
            candidates.sort(key=lambda pair: (not pair[0], pair[1].name.casefold()))
            total = len(candidates)
            for linked, component in candidates[offset:offset+PAGE]:
                rows.append(self._model(component, 'component', component.name, linked))
            note = 'Insert a separate copy. Existing components and stock stay unchanged.'
        else:
            document = design.parentDocument
            data_file = document.dataFile
            if not data_file:
                return {'part_id': self.part_id, 'part_name': part.get('name') or part.get('canonical_name'),
                        'mode': mode, 'models': [], 'folders': [], 'offset': 0, 'next_offset': None,
                        'parent': None, 'folder': 'Fusion project', 'note': 'Save this design to a Fusion project to browse its saved models. You can still use Current design.'}
            if folder_id:
                folder = self.folders.get(folder_id)
                if not folder:
                    raise ValueError('This folder selection expired. Open the model picker again.')
                parent = self.parents[folder_id]
            else:
                root = data_file.parentProject.rootFolder
                self.folders.clear(); self.parents.clear()
                root_entry = self._folder(root, None)
                folder_id = root_entry['id']; folder = root
            label = str(folder.name)
            children = folder.dataFolders
            files = folder.dataFiles
            # Page through entries without walking every project folder.
            total = children.count + files.count
            for i in range(offset, min(total, offset+PAGE)):
                if i < children.count:
                    folders.append(self._folder(children.item(i), folder_id))
                else:
                    model = files.item(i - children.count)
                    if model.id == data_file.id or str(model.fileExtension).lower() != 'f3d':
                        continue
                    rows.append(self._model(model, 'data_file', model.name, version=model.versionNumber))
            note = 'Saved Fusion designs only. Inserted as an independent copy; source geometry is not changed.'
        return {'part_id': self.part_id, 'part_name': part.get('name') or part.get('canonical_name'),
                'mode': mode, 'models': rows, 'folders': folders, 'folder_id': folder_id,
                'offset': offset, 'next_offset': offset+PAGE if offset+PAGE < total else None,
                'parent': parent, 'folder': label, 'note': note}

    def resolve(self, app, part, inventory_id, model_id):
        design = adsk.fusion.Design.cast(app.activeProduct)
        if design != self.design or inventory_id != self.inventory_id or str(part.get('item_id') or part.get('catalog_id')) != self.part_id:
            self.clear()
            raise ValueError('The design or selected part changed. Open the model picker again.')
        result = self.models.get(model_id)
        if not result or not getattr(result[1], 'isValid', True):
            raise ValueError('This model selection expired. Open the model picker again.')
        return result
