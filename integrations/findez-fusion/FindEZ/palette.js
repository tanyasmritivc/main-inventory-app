'use strict';
(() => {
  const $ = id => document.getElementById(id);
  let source = 'inventory', offset = 0, next = null, connected = false, busy = false;
  let modelPart = null, modelPage = null, allowWrites = false, generationEnabled = false, bomEnabled = false, draft = null;
  const message = (text, kind = 'notice') => { $('message').textContent = text; $('message').dataset.kind = kind; };
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
    $('session').setAttribute('aria-busy', String(value));
    if (value) message($('message').textContent || 'Working...', 'busy');
    else if ($('message').dataset.kind === 'busy') message('');
    document.querySelectorAll('button').forEach(b => { if (b.id !== 'disconnect') b.disabled = value; });
    document.querySelectorAll('[data-model-insert]').forEach(b => { b.disabled = value || !b.closest('article').querySelector('input').checked; });
    $('save-version').disabled = value || !allowWrites || !bomEnabled; $('generation-submit').disabled = value || !allowWrites || !generationEnabled;
    $('load-versions').disabled = value || !bomEnabled; $('generation-history').disabled = value || !generationEnabled;
    document.querySelectorAll('[data-cad-write]').forEach(b => { b.disabled = value || !allowWrites; });
    document.querySelectorAll('[data-generated-insert]').forEach(b => { b.disabled = value || !b.parentElement.querySelector('input[type=checkbox]').checked; });
    if (!value) { $('models-previous').disabled = !modelPage || modelPage.offset === 0; $('models-next').disabled = !modelPage || modelPage.next_offset === null; $('previous').disabled = offset === 0; $('next').disabled = next === null; $('export').disabled = !$('results').children.length; }
  }
  function browse(start = 0) {
    if (!connected || busy) return;
    offset = start; next = null;
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
    for (const name of ['inventory','catalog','bom','generate']) $(name+'-tab').setAttribute('aria-pressed', String(name === view));
    $('models').hidden = true; modelPart = null; modelPage = null;
    $('browser').hidden = view === 'bom' || view === 'generate'; $('bom').hidden = view !== 'bom'; $('generate').hidden = view !== 'generate';
    if (view === 'bom' || view === 'generate') return;
    source = view; offset = 0; next = null;
    $('location-filter').hidden = view !== 'inventory';
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
  for (const name of ['inventory','catalog','bom','generate']) $(name+'-tab').onclick = () => tab(name);
  $('previous').onclick = () => browse(Math.max(0, offset - 50));
  $('next').onclick = () => { if (next !== null) browse(next); };
  $('compare').onclick = () => { $('summary').replaceChildren(); $('results').replaceChildren(); $('warnings').replaceChildren(); message('Reading the active assembly...'); send('compare'); };
  $('export').onclick = () => send('export');
  function requestId() {
    const bytes = new Uint8Array(16); window.crypto.getRandomValues(bytes);
    bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
    const hex = Array.from(bytes, n => n.toString(16).padStart(2,'0')).join('');
    return [hex.slice(0,8),hex.slice(8,12),hex.slice(12,16),hex.slice(16,20),hex.slice(20)].join('-');
  }
  $('save-version').onclick = () => send('save_version');
  $('load-versions').onclick = () => send('versions');
  $('generation-new').onclick = () => { if (busy) return; draft=null; $('generation-form').reset(); $('generation-job').replaceChildren(); message('Enter the specification for a new model.'); };
  $('generation-history').onclick = () => send('generation_jobs');
  $('generation-form').onsubmit = event => {
    event.preventDefault();
    if (!connected || busy || !allowWrites || !generationEnabled || !$('generation-consent').checked) return;
    const spec = { name:$('generation-name').value.trim(), prompt:$('generation-prompt').value.trim(), units:$('generation-units').value, confirmed:true };
    const signature = JSON.stringify(spec);
    if (!draft || draft.signature !== signature) draft = { signature, request_id:requestId() };
    send('generate', { ...spec, request_id:draft.request_id });
  };
  function generationJob(data) {
    const target = $('generation-job'); target.replaceChildren();
    target.append(node('h3',data.name),node('p','Status: '+data.state.replaceAll('_',' ')));
    if (data.expires) target.append(node('small','Temporary result expires: '+data.expires));
    if (data.error) target.append(node('p',data.error));
    const refresh = node('button','Refresh status'); refresh.onclick=()=>send('generation_status',{id:data.id}); target.append(refresh);
    if (data.state==='pending_submission') {
      const resume=node('button','Retry submission'); resume.dataset.cadWrite='true'; resume.onclick=()=>send('generation_resume',{id:data.id}); target.append(resume);
    }
    if (data.state==='needs_input' && data.question) {
      const form=node('form'); const label=node('label',data.question.text); const answer=node('textarea'); answer.maxLength=16000; answer.required=true; label.append(answer); form.append(label);
      const button=node('button','Send clarification'); button.dataset.cadWrite='true'; form.append(button);
      let retry=null;
      form.onsubmit=event=>{ event.preventDefault(); if (!allowWrites || busy || !answer.value.trim()) return;
        if (!retry || retry.answer!==answer.value.trim()) retry={request_id:requestId(),answer:answer.value.trim()};
        send('generation_answer',{id:data.id,version:data.version,question_id:data.question.id,...retry}); };
      target.append(form);
    }
    if (['queued','running','validating','needs_input'].includes(data.state)) {
      const cancel=node('button','Cancel generation'); cancel.dataset.cadWrite='true'; cancel.onclick=()=>send('generation_cancel',{id:data.id}); target.append(cancel);
    }
    if (data.state==='succeeded') {
      const label=node('label'); const check=node('input'); check.type='checkbox';
      label.append(check,document.createTextNode(' I will verify the generated dimensions and compatibility before using this model.'));
      const insert=node('button','Insert generated STEP'); insert.dataset.generatedInsert='true'; insert.disabled=true;
      check.onchange=()=>{insert.disabled=busy || !check.checked;};
      insert.onclick=()=>{if (!busy && check.checked) send('generation_insert',{id:data.id,confirmed:true});};
      target.append(label,insert,node('p','The STEP is downloaded and verified automatically inside Fusion. It is not a manufacturer-verified model.'));
    }
    lock(false); message('');
  }
  window.fusionJavaScriptHandler = { handle(action, raw) {
    try {
      const data = JSON.parse(raw);
      if (action === 'busy') { lock(data.busy); return 'OK'; }
      if (action === 'error' || action === 'notice') { message(data.message, action); return 'OK'; }
      if (action === 'comparison_started') {
        for (const name of ['inventory','catalog','bom','generate']) $(name+'-tab').setAttribute('aria-pressed', String(name === 'bom'));
        $('models').hidden = true; $('browser').hidden = true; $('bom').hidden = false; $('generate').hidden = true;
        modelPart = null; modelPage = null;
        $('summary').replaceChildren(); $('results').replaceChildren(); $('warnings').replaceChildren();
        message('Comparing ' + data.name + ' with your connected inventory...'); return 'OK';
      }
      if (action === 'generation_job') { generationJob(data); return 'OK'; }
      if (action === 'generation_jobs') {
        $('generation-jobs').replaceChildren();
        for (const job of data.jobs) { const b=node('button',job.name || job.created_at); b.onclick=()=>send('generation_status',{id:job.id}); $('generation-jobs').append(b); }
        if (!data.jobs.length) $('generation-jobs').append(node('p','No generation jobs in this inventory yet.'));
        return 'OK';
      }
      if (action === 'versions') {
        $('versions').replaceChildren();
        for (const version of data.versions) { const b=node('button',(version.document?.name || 'Design')+' / BOM '+version.version+' / '+version.created_at); b.onclick=()=>send('version',{id:version.id}); $('versions').append(b); }
        if (!data.versions.length) $('versions').append(node('p','No saved BOM versions in this inventory yet.'));
        if (data.offset>0) { const b=node('button','Newer versions'); b.onclick=()=>send('versions',{offset:Math.max(0,data.offset-50)}); $('versions').append(b); }
        if (data.next_offset!==null) { const b=node('button','Older versions'); b.onclick=()=>send('versions',{offset:data.next_offset}); $('versions').append(b); }
        return 'OK';
      }
      if (action === 'version') {
        window.fusionJavaScriptHandler.handle('comparison',JSON.stringify({...data.comparison,historical:true}));
        message('Saved BOM version '+data.version+' from '+data.created_at+'. Historical stock snapshot; compare the open design for current availability.'); return 'OK';
      }
      if (action === 'models') { showModels(data); return 'OK'; }
      if (action === 'pairing') { $('code').textContent = data.code; message('Compare this code with the browser, select an inventory and approve.'); return 'OK'; }
      if (action === 'disconnected') {
        connected = false; allowWrites = false; generationEnabled = false; bomEnabled = false; draft = null; $('versions').replaceChildren(); $('generation-job').replaceChildren(); $('generation-jobs').replaceChildren(); modelPart = null; modelPage = null; $('model-entries').replaceChildren(); $('models').hidden = true; $('search-explanation').textContent = ''; lock(false); $('session').hidden = true; $('sign-in').hidden = false;
        $('code').textContent = ''; $('parts').replaceChildren(); $('results').replaceChildren(); $('summary').replaceChildren(); $('warnings').replaceChildren();
        message('Disconnected. Sign in to choose an inventory.'); return 'OK';
      }
      if (action === 'connected') {
        connected = true; allowWrites = data.allow_cad_writes === true;
        generationEnabled = data.generation_enabled === true; bomEnabled = data.saved_bom_enabled === true;
        $('generation-note').textContent = !generationEnabled ? 'Model generation is unavailable on this server. You can still choose models from your Fusion project.' : !allowWrites ? 'Reconnect and approve CAD writing access to generate a model.' : 'Ready to generate. Review the specification before submitting.'; $('write-note').textContent = allowWrites ? 'Saved versions and corrections are shared with this inventory. Stock is not changed.' : 'To save BOMs or generate models, reconnect and approve CAD writing access.'; lock(false); $('sign-in').hidden = true; $('session').hidden = false;
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
          if (allowWrites && line.review_token && !data.historical) {
            const details=node('details'); details.append(node('summary','Correct this match'));
            const select=node('select'); select.append(new Option('Choose an inventory item',''));
            for (const item of line.candidates || []) select.append(new Option(item.name+' / '+(item.part_number || 'No part number')+' / '+(item.location || 'Unsorted'),item.item_id));
            const label=node('label','Match to'); label.append(select); details.append(label);
            for (const [decision,title] of [['match','Remember this match'],['no_match','None match'],['reset','Forget correction']]) {
              const b=node('button',title); b.dataset.cadWrite='true';
              b.onclick=()=>{ if (!busy && allowWrites && (decision!=='match' || select.value)) send('correct',{key:line.key,decision,item_id:decision==='match'?select.value:null}); };
              details.append(b);
            }
            details.append(node('small','Shared with this inventory. Confirm exact specifications; this does not change stock.')); row.append(details);
          }
          $('results').append(row);
        }
        lock(false); message(`Compared ${data.document.name}. Refresh after design or stock changes.`); return 'OK';
      }
    } catch { message('The response could not be displayed. Try again.'); }
    return 'OK';
  }};
  send('ready');
})();
