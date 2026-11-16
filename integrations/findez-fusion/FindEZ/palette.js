'use strict';
(() => {
  const $ = id => document.getElementById(id);
  let source = 'inventory', offset = 0, next = null, connected = false, busy = false;
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
    if (!value) { $('previous').disabled = offset === 0; $('next').disabled = next === null; $('export').disabled = !$('results').children.length; }
  }
  function browse(start = 0) {
    if (!connected || busy) return;
    offset = start;
    $('parts').replaceChildren();
    const args = { q: $('query').value, offset };
    if (source === 'inventory' && $('location').value !== '*') args.location = $('location').value;
    send(source, args);
  }
  function tab(view) {
    if (busy) return;
    for (const name of ['inventory','catalog','bom']) $(name+'-tab').setAttribute('aria-pressed', String(name === view));
    $('browser').hidden = view === 'bom'; $('bom').hidden = view !== 'bom';
    if (view === 'bom') return;
    source = view; offset = 0; next = null;
    $('location').hidden = $('location-label').hidden = view !== 'inventory';
    $('query').placeholder = view === 'inventory' ? 'Name, part number or location' : 'Catalog part name';
    $('source-note').textContent = view === 'inventory' ? 'Your recorded inventory. Available quantities subtract reservations and active checkouts.' : 'Global catalog. These parts are not necessarily owned by your team. Models and prices are not connected yet.';
    browse();
  }
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
      if (action === 'pairing') { $('code').textContent = data.code; message('Compare this code with the browser, select an inventory and approve.'); return 'OK'; }
      if (action === 'disconnected') {
        connected = false; lock(false); $('session').hidden = true; $('sign-in').hidden = false;
        $('code').textContent = ''; $('parts').replaceChildren(); $('results').replaceChildren(); $('summary').replaceChildren(); $('warnings').replaceChildren();
        message('Disconnected. Sign in to choose an inventory.'); return 'OK';
      }
      if (action === 'connected') {
        connected = true; lock(false); $('sign-in').hidden = true; $('session').hidden = false;
        $('inventory-name').textContent = data.inventory_name; $('workspace-name').textContent = data.workspace_name;
        message('Connected. This session expires in eight hours.'); tab('inventory'); return 'OK';
      }
      if (action === 'inventory' || action === 'catalog') {
        const values = data.items || data.parts || [];
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
          if (action === 'inventory') {
            card.append(node('p',part.availability_known ? `${part.available} available` : 'Availability needs review','quantity'));
            card.append(node('small',`${part.on_hand ?? "Unknown"} on hand · ${part.reserved} reserved · ${part.checked_out} checked out`));
            card.append(node('small',part.location || 'Unsorted'));
          } else card.append(node('small','Manufacturer-verified catalog identity. Not a stock record.'));
          if (part.specifications && Object.keys(part.specifications).length) {
            const details = node('details'); details.append(node('summary','Specifications'));
            details.append(node('pre',JSON.stringify(part.specifications,null,2),'specs')); card.append(details);
          }
          card.append(node('small','No linked CAD model. Select a local STEP or F3D file.'));
          const insert = node('button','Insert local model'); insert.onclick = () => send('insert',{id:part.item_id || part.catalog_id}); card.append(insert); container.append(card);
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
