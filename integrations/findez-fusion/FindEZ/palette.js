'use strict';
(() => {
  const $ = id => document.getElementById(id);
  let source = 'inventory', offset = 0, next = null, connected = false, busy = false;
  let modelPart = null, modelPage = null;
  const message = text => { $('message').textContent = text; };
  function send(action, data = {}) {
    if (!window.adsk) { message('Open this panel from the FindEZ Fusion add-in.'); return; }
    window.adsk.fusionSendData(action, JSON.stringify(data));
  }
  function node(tag, text, cls) {
    const element = document.createElement(tag);
    if (text !== undefined) element.textContent = String(text ?? '');
    if (cls) element.className = cls;
    return element;
  }
  function lock(value) {
    busy = value;
    document.querySelectorAll('button').forEach(b => { if (b.id !== 'disconnect') b.disabled = value; });
    document.querySelectorAll('[data-model-insert]').forEach(b => { b.disabled = value || !b.closest('article').querySelector('input').checked; });
    if (!value) { $('models-previous').disabled = !modelPage || modelPage.offset === 0; $('models-next').disabled = !modelPage || modelPage.next_offset === null; $('previous').disabled = offset === 0; $('next').disabled = next === null; $('export').disabled = !$('results').children.length; }
  }
  function browse(start = 0) {
    if (!connected || busy) return;
    offset = start;
    $('parts').replaceChildren();
    $('search-explanation').textContent = '';
    const query = $('query').value.trim();
    if ($('search-mode').value === 'ai' && query) {
      const args = { query, source };
      if (source === 'inventory' && $('location').value !== '*') args.location = $('location').value;
      message('Finding parts with AI...'); send('search', args); return;
    }
    if (query.length > 100) { message('Use 100 characters or fewer for keyword search.'); return; }
    const args = { q: query, offset };
    if (source === 'inventory' && $('location').value !== '*') args.location = $('location').value;
    send(source, args);
  }
  function tab(view) {
    if (busy) return;
    for (const name of ['inventory','catalog','bom']) $(name+'-tab').setAttribute('aria-pressed', String(name === view));
    $('models').hidden = true; modelPart = null; modelPage = null;
    $('browser').hidden = view === 'bom'; $('bom').hidden = view !== 'bom';
    if (view === 'bom') return;
    source = view; offset = 0; next = null;
    $('location').hidden = $('location-label').hidden = view !== 'inventory';
    $('query').placeholder = view === 'inventory' ? 'Find 12 M4 screws, or bearings for an 8mm shaft' : 'Describe the catalog part you need';
    $('source-note').textContent = view === 'inventory' ? 'Your recorded inventory. Available quantities subtract reservations and active checkouts.' : 'Global catalog. These parts are not necessarily owned by your team. Prices and manufacturer CAD downloads are not connected. You can insert geometry from your Fusion project.';
    browse();
  }
  function modelBrowse(mode = 'design', folder = null, start = 0) {
    if (!modelPart || busy) return;
    $('model-entries').replaceChildren();
    message('Loading Fusion models...');
    send('models', { id: modelPart, mode, folder_id: folder, offset: start });
  }
  function showModels(data) {
    modelPage = data; modelPart = data.part_id;
    $('browser').hidden = true; $('bom').hidden = true; $('models').hidden = false;
    $('model-part').textContent = 'For: ' + data.part_name;
    $('model-folder').textContent = data.folder; $('model-note').textContent = data.note;
    $('model-parent').hidden = !data.parent;
    const entries = $('model-entries'); entries.replaceChildren();
    for (const folder of data.folders) {
      const button = node('button', 'Folder: ' + folder.name);
      button.onclick = () => modelBrowse('project', folder.id);
      entries.append(button);
    }
    for (const model of data.models) {
      const card = node('article', undefined, 'part'); card.append(node('h3', model.name));
      card.append(node('small', model.source + (model.version ? ' · Version ' + model.version : '')));
      if (model.linked) card.append(node('small', 'Previously associated with this part in this design.'));
      const label = node('label'); const check = document.createElement('input'); check.type = 'checkbox';
      label.append(check, document.createTextNode(' I checked this model matches the selected part.')); card.append(label);
      const insert = node('button', 'Insert into design'); insert.dataset.modelInsert = 'true'; insert.disabled = true;
      check.onchange = () => { insert.disabled = busy || !check.checked; };
      insert.onclick = () => {
        if (!check.checked || busy) return;
        send('insert_model', { id: modelPart, model_id: model.id, confirmed: true });
      };
      card.append(insert); entries.append(card);
    }
    if (!data.models.length && !data.folders.length) entries.append(node('p', 'No insertable models in this view. Choose Fusion project or another folder.'));
    lock(false); message('');
  }
  $('models-design').onclick = () => modelBrowse('design');
  $('models-project').onclick = () => modelBrowse('project');
  $('model-parent').onclick = () => modelBrowse('project', modelPage.parent);
  $('models-previous').onclick = () => modelBrowse(modelPage.mode, modelPage.folder_id, Math.max(0, modelPage.offset - 40));
  $('models-next').onclick = () => modelBrowse(modelPage.mode, modelPage.folder_id, modelPage.next_offset);
  $('models-close').onclick = () => { $('models').hidden = true; $('browser').hidden = false; };
  $('model-local').onclick = () => send('insert_local', { id: modelPart });
  $('connect').onclick = () => { message('Opening secure sign-in in your browser...'); send('connect'); };
  $('disconnect').onclick = () => send('disconnect');
  $('search').onsubmit = event => { event.preventDefault(); browse(); };
  $('location').onchange = () => browse();
  for (const name of ['inventory','catalog','bom']) $(name+'-tab').onclick = () => tab(name);
  $('previous').onclick = () => browse(Math.max(0, offset - 50));
  $('next').onclick = () => { if (next !== null) browse(next); };
  $('compare').onclick = () => { $('summary').replaceChildren(); $('results').replaceChildren(); $('warnings').replaceChildren(); message('Reading the active assembly...'); send('compare'); };
  $('export').onclick = () => send('export');
  window.fusionJavaScriptHandler = { handle(action, raw) {
    try {
      const data = JSON.parse(raw);
      if (action === 'busy') { lock(data.busy); return 'OK'; }
      if (action === 'error' || action === 'notice') { message(data.message); return 'OK'; }
      if (action === 'comparison_started') {
        for (const name of ['inventory','catalog','bom']) $(name+'-tab').setAttribute('aria-pressed', String(name === 'bom'));
        $('models').hidden = true; $('browser').hidden = true; $('bom').hidden = false;
        modelPart = null; modelPage = null;
        $('summary').replaceChildren(); $('results').replaceChildren(); $('warnings').replaceChildren();
        message('Comparing ' + data.name + ' with your connected inventory...'); return 'OK';
      }
      if (action === 'models') { showModels(data); return 'OK'; }
      if (action === 'pairing') { $('code').textContent = data.code; message('Compare this code with the browser, select an inventory and approve.'); return 'OK'; }
      if (action === 'disconnected') {
        connected = false; modelPart = null; modelPage = null; $('model-entries').replaceChildren(); $('models').hidden = true; $('search-explanation').textContent = ''; lock(false); $('session').hidden = true; $('sign-in').hidden = false;
        $('code').textContent = ''; $('parts').replaceChildren(); $('results').replaceChildren(); $('summary').replaceChildren(); $('warnings').replaceChildren();
        message('Disconnected. Sign in to choose an inventory.'); return 'OK';
      }
      if (action === 'connected') {
        connected = true; lock(false); $('sign-in').hidden = true; $('session').hidden = false;
        $('inventory-name').textContent = data.inventory_name; $('workspace-name').textContent = data.workspace_name;
        message('Connected. This session expires in eight hours.'); tab('inventory'); return 'OK';
      }
      if (action === 'inventory' || action === 'catalog' || action === 'search') {
        if (action === 'search' && data.intent === 'clarify') {
          $('parts').replaceChildren(); $('search-explanation').textContent = data.notice;
          next = null; offset = 0; $('page').textContent = ''; lock(false); message(''); return 'OK';
        }
        const resultSource = action === 'search' ? data.source : action;
        const values = resultSource === 'inventory' ? (data.items || []) : (data.parts || []);
        if (action === 'search') $('search-explanation').textContent = 'AI searched: ' + data.interpreted.terms.join(', ') + '. ' + (data.interpreted.constraints.length ? 'Requested: ' + data.interpreted.constraints.join(', ') + '. ' : '') + data.notice + (data.truncated ? ' Showing a limited set; narrow your question.' : '');
        const container = $('parts'); container.replaceChildren();
        if (data.locations) {
          const selected = $('location').value;
          $('location').replaceChildren(new Option('All locations','*'));
          for (const location of data.locations) $('location').add(new Option(location || 'Unsorted',location));
          $('location').value = data.locations.includes(selected) ? selected : '*';
        }
        for (const part of values) {
          const card = node('article',undefined,'part'); card.append(node('h3',part.name || part.canonical_name));
          card.append(node('p',[part.brand,part.part_number].filter(Boolean).join(' · ')));
          if (resultSource === 'inventory') {
            card.append(node('p',part.availability_known ? `${part.available} available` : 'Availability needs review','quantity'));
            card.append(node('small',`${part.on_hand ?? "Unknown"} on hand · ${part.reserved} reserved · ${part.checked_out} checked out`));
            card.append(node('small',part.location || 'Unsorted'));
          } else card.append(node('small','Manufacturer-verified catalog identity. Not a stock record.'));
          if (part.specifications && Object.keys(part.specifications).length) {
            const details = node('details'); details.append(node('summary','Specifications'));
            details.append(node('pre',JSON.stringify(part.specifications,null,2),'specs')); card.append(details);
          }
          if (part.search_evidence) {
            card.append(node('small', 'Found by: ' + part.search_evidence.matched_terms.join(', ')));
            if (part.search_evidence.unverified_constraints.length) card.append(node('small', 'Not established by saved records: ' + part.search_evidence.unverified_constraints.join(', ')));
            if (part.requested_quantity !== null) card.append(node('small', `${part.requested_quantity} requested · ${part.shortage_for_request === null ? 'Shortage unknown' : part.shortage_for_request + ' short for this record'}`));
          }
          const insert = node('button','Choose Fusion model'); insert.onclick = () => { modelPart = part.item_id || part.catalog_id; modelBrowse(); }; card.append(insert); container.append(card);
        }
        if (!values.length) container.append(node('p','No matching parts found.'));
        next = data.next_offset ?? null; offset = data.offset || 0;
        $('page').textContent = values.length ? `${offset + 1}-${offset + values.length}${data.total !== null ? ` of ${data.total}` : ''}` : '';
        lock(false); message(''); return 'OK';
      }
      if (action === 'comparison') {
        const summary = data.summary;
        $('summary').textContent = `${summary.covered_units} of ${summary.required_units} required units covered`;
        $('warnings').replaceChildren(...data.warnings.map(w => node('p',w)));
        $('results').replaceChildren();
        for (const line of data.items) {
          const row = node('article',undefined,'result'); row.append(node('h3',line.name));
          row.append(node('span',line.status.replaceAll('_',' '),'status '+line.status));
          row.append(node('p',`${line.required} required · ${line.assigned} assigned · ${line.missing} unmatched`));
          if (line.status === 'needs_review') row.append(node('small','Confirm the exact part before treating this as a purchase requirement.'));
          for (const match of line.matches) row.append(node('small',`${match.evidence}: ${match.assigned} from ${match.location || 'Unsorted'}`));
          $('results').append(row);
        }
        lock(false); message(`Compared ${data.document.name}. Refresh after design or stock changes.`); return 'OK';
      }
    } catch { message('The response could not be displayed. Try again.'); }
    return 'OK';
  }};
  send('ready');
})();
