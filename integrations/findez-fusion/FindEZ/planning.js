'use strict';
window.createFindEZPlanning=({$,node,send,message})=>{
  let versions=[],chosen=[],busy=false,enabled=false;
  function button(text,click){const b=node('button',text);b.type='button';b.onclick=click;b.disabled=busy;return b;}
  function render(){
    const target=$('planning-selection');target.replaceChildren();
    for(const v of versions){
      const label=node('label'),check=node('input');check.type='checkbox';check.checked=chosen.includes(v.id);check.disabled=busy;
      check.onchange=()=>{if(check.checked){if(chosen.length>=20){check.checked=false;message('Select up to twenty projects.');return;}chosen.push(v.id);}else chosen=chosen.filter(id=>id!==v.id);render();};
      label.append(check,document.createTextNode((v.document?.name || 'Design')+' / BOM '+v.version));target.append(label);
    }
    const priority=$('planning-priority');priority.replaceChildren();
    chosen.forEach((id,index)=>{const v=versions.find(v=>v.id===id);const row=node('p',(index+1)+'. '+(v?.document?.name || 'Design')+' / BOM '+v?.version);if(index)row.append(button('Move earlier',()=>{[chosen[index-1],chosen[index]]=[chosen[index],chosen[index-1]];render();}));priority.append(row);});
    $('planning-run').disabled=busy || !enabled || !chosen.length;
    $('diff-run').disabled=busy || !enabled || !$('diff-before').value || !$('diff-after').value || $('diff-before').value===$('diff-after').value;
  }
  $('planning-run').onclick=()=>{if(!busy && chosen.length)send('plan_projects',{version_ids:chosen});};
  $('diff-run').onclick=()=>send('revision_diff',{before:$('diff-before').value,after:$('diff-after').value});
  $('diff-before').onchange=render;$('diff-after').onchange=render;
  return {lock(value){busy=value;render();},configure(context){enabled=!!context?.saved_bom_enabled;versions=[];chosen=[];$('planning-results').replaceChildren();$('diff-results').replaceChildren();for(const id of ['diff-before','diff-after'])$(id).replaceChildren(new Option('Choose saved BOM',''));render();},
    handle(action,data){
      if(action==='versions'){
        versions=data.versions;chosen=chosen.filter(id=>versions.some(v=>v.id===id));
        for(const id of ['diff-before','diff-after']){const field=$(id),value=field.value;field.replaceChildren(new Option('Choose saved BOM',''));for(const v of versions)field.add(new Option((v.document?.name || 'Design')+' / BOM '+v.version,v.id));field.value=versions.some(v=>v.id===value)?value:'';}
        render();return false;
      }
      if(action==='planning'){
        const target=$('planning-results');target.replaceChildren(node('p',data.note),node('small','Inventory read '+data.inventory_as_of));
        for(const warning of data.warnings)target.append(node('p',warning));
        for(const p of data.projects){const card=node('article',undefined,'result');card.append(node('h3',p.priority+'. '+p.name),node('p',p.assigned+' assigned / '+p.required+' required · '+p.missing+' unmatched · '+p.review_lines+' review lines'));for(const line of p.items)if(line.missing || line.status==='needs_review')card.append(node('small',line.name+': '+line.missing+' unmatched ('+line.status+')'));target.append(card);}
        target.append(node('h3','On order — not on hand'));for(const line of data.incoming)target.append(node('p',line.name+': '+line.quantity+' units / '+line.project));if(!data.incoming.length)target.append(node('p','No open incoming order lines.'));return true;
      }
      if(action==='revision_diff'){
        const target=$('diff-results');target.replaceChildren(node('p','Saved requirements only; no geometry or current-stock check.'));
        for(const r of data.changes)target.append(node('p',r.name+': '+r.before+' → '+r.after+(r.needs_review?' · identity needs review':'')));
        if(!data.changes.length)target.append(node('p','No requirement changes.'));return true;
      }
      return false;
    }};
};
