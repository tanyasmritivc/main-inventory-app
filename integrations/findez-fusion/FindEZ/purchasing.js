'use strict';
// Native palette controls share the web purchasing service and transaction rules.
window.createFindEZPurchasing = ({ $, node, send, message, requestId }) => {
  let context = null, busy = false, plan = null, pending = null, version = null, destination = null, storageError = false;
  const root = $('purchase-detail');
  const allowed = () => context?.allow_purchasing === true;
  const storageKey = () => 'findez.purchase.pending.v1:' + context.purchase_context;
  function retain(value) {
    // Store only the user's exact request, never bearer/provider credentials.
    try {
      if (value) localStorage.setItem(storageKey(), JSON.stringify(value));
      else localStorage.removeItem(storageKey());
      pending = value; return true;
    } catch { storageError = true; message('Pending changes could not be saved locally. Purchasing is paused to protect retry safety.', 'error'); return false; }
  }
  function controls() {
    const blocked = busy || !allowed() || storageError;
    document.querySelectorAll('#purchases button').forEach(b => { b.disabled = blocked || (b.dataset.write === 'true' && !!pending); });
    $('purchase-create').disabled = blocked || !!pending || !version;
    $('purchase-retry').hidden = !pending;
    $('purchase-retry').disabled = blocked || !pending;
    $('purchase-pending').textContent = pending ? 'A change is unconfirmed. Retry the same change before starting another one. Your request is retained on this computer.' : '';
  }
  function read(id) { if (!busy && allowed()) send('purchase_detail', { id }); }
  function write(body, id = null) {
    if (busy || !allowed() || pending || storageError) return;
    const change = { id, body: { ...body, request_id: requestId() } };
    if (retain(change)) { controls(); send('purchase_write', change); }
  }
  function act(action, data = {}) {
    if (plan) write({ action, expected_revision: plan.revision, ...data }, plan.id);
  }
  function button(text, click, writeControl = false) {
    const b = node('button', text); b.type = 'button'; b.onclick = click;
    if (writeControl) b.dataset.write = 'true';
    return b;
  }
  function field(form, labelText, name, type = 'text', value = '', required = true) {
    const label = node('label', labelText), input = node('input');
    input.name = name; input.type = type; input.value = value; input.required = required;
    input.maxLength = 1000;
    if (type === 'number') { input.min = '1'; input.max = '1000000'; input.step = '1'; }
    label.append(input); form.append(label); return input;
  }
  function quoteForm(line) {
    const details = node('details'); details.append(node('summary', 'Add supplier quote'));
    const form = node('form'); form.className = 'purchase-form';
    const vendor = field(form, 'Supplier', 'vendor'); vendor.maxLength = 150;
    field(form, 'HTTPS product URL', 'product_url', 'url');
    field(form, 'Source / quotation reference', 'source_note');
    const currency = field(form, 'Currency (three-letter code)', 'currency', 'text', 'USD'); currency.pattern = '[A-Z]{3}'; currency.maxLength = 3;
    const price = field(form, 'Price per individual unit', 'unit_price', 'text'); price.pattern = '[0-9]+(\\.[0-9]{1,6})?';
    field(form, 'Units per pack', 'pack_size', 'number', '1');
    field(form, 'Minimum order units', 'minimum_quantity', 'number', '1');
    field(form, 'Quote date and time (local)', 'quoted_at', 'datetime-local');
    field(form, 'Valid until (local)', 'valid_until', 'datetime-local');
    const availability = node('select'); availability.name = 'availability';
    for (const [v,t] of [['unknown','Availability unknown'],['in_stock','Supplier reports in stock'],['out_of_stock','Out of stock']]) availability.add(new Option(t,v));
    const availabilityLabel=node('label','Supplier availability'); availabilityLabel.append(availability); form.append(availabilityLabel);
    const tiers=field(form,'Optional all-unit breaks: quantity, price; quantity, price','tiers','text','',false);
    const confirmLabel=node('label'), confirm=node('input'); confirm.type='checkbox'; confirm.required=true;
    confirmLabel.append(confirm, document.createTextNode(' I verified this quote is for the exact required part and variant.')); form.append(confirmLabel);
    const save=node('button','Save quote'); save.dataset.write='true'; form.append(save);
    form.onsubmit=e=>{
      e.preventDefault(); if (!form.reportValidity() || !confirm.checked) return;
      const data=Object.fromEntries(new FormData(form).entries());
      try {
        const breaks=tiers.value.trim() ? tiers.value.split(';').map(entry=>{const values=entry.split(',').map(v=>v.trim()); if(values.length!==2 || !/^\d+$/.test(values[0]) || !/^\d+(\.\d{1,6})?$/.test(values[1])) throw Error(); return {minimum_quantity:Number(values[0]),unit_price:values[1]};}) : [];
        act('quote',{line_id:line.id,quote:{...data,pack_size:Number(data.pack_size),minimum_quantity:Number(data.minimum_quantity),
          quoted_at:new Date(data.quoted_at).toISOString(),valid_until:new Date(data.valid_until).toISOString(),tiers:breaks,exact_part_confirmed:true}});
      } catch { message('Check the quote dates and bulk price breaks.', 'error'); }
    };
    details.append(form); return details;
  }
  function receiveForm(line) {
    const details=node('details'); details.append(node('summary','Receive a delivery'));
    const form=node('form'); form.className='purchase-form';
    const search=field(form,'Find existing stock destination','search','search',line.part_number || line.name);
    const results=node('select'); results.required=true; results.add(new Option('Search for a destination',''));
    form.append(button('Find destination',()=>{ if (search.value.trim().length<2) {message('Enter at least two characters.');return;} destination={plan:plan.id,line:line.id,select:results}; send('purchase_candidates',{q:search.value.trim().slice(0,100)}); }));
    const label=node('label','Destination item and location'); label.append(results); form.append(label);
    const quantity=field(form,'Units received in this delivery','quantity','number'); quantity.max=String(line.selected_quote.estimate.order_quantity-line.received);
    const check=node('input'); check.type='checkbox'; check.required=true; const checkLabel=node('label');
    checkLabel.append(check,document.createTextNode(' I checked the exact delivered variant and destination. Confirming adds these units to stock.')); form.append(checkLabel);
    const submit=node('button','Confirm delivery and add stock');submit.dataset.write='true';form.append(submit);
    form.onsubmit=e=>{e.preventDefault();if(form.reportValidity() && check.checked && results.value) act('receive',{line_id:line.id,item_id:results.value,quantity:Number(quantity.value),identity_confirmed:true});};
    details.append(form);return details;
  }
  function showPlan(data) {
    if (data.inventory_id!==context?.inventory_id) throw Error('Inventory mismatch');
    plan=data;destination=null;root.replaceChildren(node('h3',data.name),node('p','Status: '+data.state+' · Revision '+data.revision));
    root.append(node('small','Inventory reconciled '+data.inventory_as_of+'. Quantities may have changed since then.'));
    for(const [currency,total] of Object.entries(data.totals)) root.append(node('p',currency+' '+total+' quoted subtotal'));
    root.append(node('small','Quoted lines only. Shipping and tax excluded. Currencies are kept separate.'),button('Refresh plan',()=>read(data.id)),button('Export by vendor',()=>send('purchase_export',{id:data.id})));
    if(context.can_approve_purchases && data.state==='draft') root.append(button('Approve quoted plan',()=>act('approve'),true),button('Cancel draft',()=>act('cancel'),true));
    if(context.can_approve_purchases && data.state==='approved') {
      root.append(button('Reopen for changes',()=>act('reopen'),true),button('Cancel approved plan',()=>act('cancel'),true));
      const form=node('form');form.className='purchase-form';const ref=field(form,'Vendor order references (record after ordering)','order_reference');
      const check=node('input');check.type='checkbox';check.required=true;const label=node('label');label.append(check,document.createTextNode(' I have placed these orders with the suppliers. This only records the order.'));form.append(label);
      const save=node('button','Record placed order');save.dataset.write='true';form.append(save);
      form.onsubmit=e=>{e.preventDefault();if(form.reportValidity() && check.checked)act('order',{order_reference:ref.value.trim()});};root.append(form);
    }
    for(const line of data.lines) {
      const card=node('article',undefined,'part');card.append(node('h3',line.name),node('p',[line.manufacturer,line.part_number].filter(Boolean).join(' · ')),node('p',line.required+' required · '+line.available+' assigned when planned · '+line.quantity+' shortage'));
      if(Object.keys(line.specifications || {}).length) card.append(node('p', 'Required specifications: '+Object.entries(line.specifications).map(([key,value])=>key+': '+value).join(' / ')));
      const selected=line.selected_quote;
      if(selected) card.append(node('p','Selected: '+selected.vendor+' · '+selected.currency+' '+selected.estimate.subtotal+' / '+selected.estimate.order_quantity+' units'),node('small',line.received+' received · '+(data.state==='ordered'? selected.estimate.order_quantity-line.received:0)+' on order'));
      for(const quote of line.quotes) {
        const info=node('details');info.append(node('summary',quote.vendor+' · '+quote.currency+' '+quote.estimate.subtotal+' / '+quote.estimate.order_quantity+' units'));
        info.append(node('p','Source: '+quote.source_note),node('small',quote.product_url),node('p','Quoted '+quote.quoted_at+' · Valid until '+quote.valid_until),node('small','Availability: '+quote.availability+' · '+quote.estimate.surplus_quantity+' extra units from packs or bulk pricing'));
        if(data.state==='draft' && quote.availability!=='out_of_stock' && new Date(quote.valid_until)>new Date()) info.append(button('Use this quote',()=>act('select_quote',{line_id:line.id,quote_id:quote.id}),true));
        card.append(info);
      }
      if(data.state==='draft') card.append(quoteForm(line));
      if(data.state==='ordered' && selected && line.received<selected.estimate.order_quantity) card.append(receiveForm(line));
      root.append(card);
    }
    controls();
  }
  $('purchase-refresh').onclick=()=>{if(allowed())send('purchase_list');};
  $('purchase-load-versions').onclick=()=>send('versions');
  $('purchase-version').onchange=()=>{version=$('purchase-version').value || null;controls();};
  $('purchase-create').onclick=()=>{if(version)write({bom_version_id:version});};
  $('purchase-retry').onclick=()=>{if(!busy && allowed() && pending)send('purchase_write',pending);};
  return {
    lock(value){busy=value;controls();},
    configure(data){
      context=data;plan=null;destination=null;version=null;pending=null;storageError=false;root.replaceChildren();$('purchase-list').replaceChildren();$('purchase-version').replaceChildren(new Option('Choose a saved BOM',''));
      if(data?.purchase_context) {
        try { const value=JSON.parse(localStorage.getItem(storageKey()) || 'null'); if(value && typeof value==='object' && value.body?.request_id)pending=value; }
        catch { storageError=true; message('The pending purchase request could not be loaded. Do not repeat an uncertain delivery; check the web purchase plan.', 'error'); }
      }
      $('purchase-note').textContent=storageError?'Local request storage is unavailable or damaged. Do not repeat an uncertain delivery; reconcile the plan on the website first.':allowed()?'Quotes, plans and receipts are shared with this inventory. Receiving requires explicit confirmation. No checkout or payment is performed.':'Reconnect and enable the optional purchase plans and receiving permission to use this view.';
      controls();
    },
    handle(action,data){
      if(action==='versions') {
        const selected=version;$('purchase-version').replaceChildren(new Option('Choose a saved BOM',''));
        for(const v of data.versions)$('purchase-version').add(new Option((v.document?.name || 'Design')+' / BOM '+v.version+' / '+v.created_at,v.id));
        if(selected && data.versions.some(v=>v.id===selected))$('purchase-version').value=selected;
        else version=null;controls();return false;
      }
      if(action==='version_saved' || action==='version') {
        version=data.id;if(!Array.from($('purchase-version').options).some(o=>o.value===data.id))$('purchase-version').add(new Option('BOM version '+data.version,data.id));
        $('purchase-version').value=data.id;controls();return false;
      }
      if(!action.startsWith('purchase_'))return false;
      if(action==='purchase_error') {
        if([400,404,409,422,429].includes(data.status))retain(null);
        message(data.message,'error');controls();return true;
      }
      if(!allowed())return true;
      if(action==='purchase_saved') {
        if(data.inventory_id!==context.inventory_id)throw Error('Inventory mismatch');
        if(retain(null)){message('Purchase change saved.');read(data.id);}controls();return true;
      }
      if(action==='purchase_detail'){showPlan(data);return true;}
      if(action==='purchase_list') {
        if(data.inventory_id!==context.inventory_id)throw Error('Inventory mismatch');
        $('purchase-list').replaceChildren();
        for(const p of data.plans)$('purchase-list').append(button(p.name+' · '+p.state,()=>read(p.id)));
        if(!data.plans.length)$('purchase-list').append(node('p','No purchase plans yet. Choose a saved BOM with confirmed shortages.'));
        if(data.next_offset!==null)$('purchase-list').append(button('Older plans',()=>send('purchase_list',{offset:data.next_offset})));
        controls();return true;
      }
      if(action==='purchase_candidates') {
        if(data.inventory_id!==context.inventory_id || !destination || plan?.id!==destination.plan)return true;
        destination.select.replaceChildren(new Option('Choose the exact delivered part',''));
        for(const item of data.items)destination.select.add(new Option(item.name+' / '+(item.part_number || 'No part number')+' / '+(item.location || 'Unsorted'),item.item_id));
        message(data.items.length?'Confirm the destination and delivered quantity.':'No matching stock record. Create the destination item in FindEZ before receiving.');
        return true;
      }
      return false;
    }
  };
};
