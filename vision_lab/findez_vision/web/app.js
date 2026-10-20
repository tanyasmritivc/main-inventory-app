"use strict";
const $ = (id) => document.getElementById(id);
let state, sample, annotation, image, selected = -1, draft = [], dirty = false, busy = false, dragging = null;
let readOnly = false;
const colors = ["#ed7e32","#468aab","#815fa0","#3f9473","#b55c75"];
function notice(message, error=false) { $("notice").textContent=message; $("notice").className="notice"+(error?" error":""); }
function changed() { dirty=true; annotation.status="draft"; $("checked").checked=false; buttons(); }
function buttons() {
  const blocked=busy||readOnly;
  for(const id of ["label","identity","ocr","reviewer","checked","remove"]) $(id).disabled=blocked;
  $("verify").disabled=blocked || !$("checked").checked || !$("reviewer").value.trim() || draft.length>0;
  $("save-draft").disabled=blocked || draft.length>0;
  $("finish").disabled=blocked || draft.length<3;
  $("undo").disabled=blocked || !draft.length;
  $("discard").disabled=blocked || !draft.length;
}
function draw() {
  if (!image) return;
  const canvas=$("canvas"),ctx=canvas.getContext("2d");
  const displayWidth=Math.max(canvas.clientWidth,1);
  canvas.width=Math.max(sample.image.width,Math.ceil(displayWidth*window.devicePixelRatio));
  canvas.height=Math.round(canvas.width*sample.image.height/sample.image.width);
  ctx.setTransform(canvas.width/sample.image.width,0,0,canvas.height/sample.image.height,0,0);
  ctx.drawImage(image,0,0,sample.image.width,sample.image.height);
  const scale=sample.image.width/displayWidth,line=2*scale;
  function polygon(points,color,fill) {
    if(!points.length)return;
    ctx.beginPath();ctx.moveTo(...points[0]);for(const p of points.slice(1))ctx.lineTo(...p);
    if(fill){ctx.closePath();ctx.globalAlpha=.17;ctx.fillStyle=color;ctx.fill();ctx.globalAlpha=1;}
    ctx.strokeStyle=color;ctx.lineWidth=line;ctx.stroke();
    for(const p of points){ctx.beginPath();ctx.arc(...p,3*scale,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();}
  }
  annotation.objects.forEach((o,i)=>(o.polygons||[]).forEach(p=>polygon(p,colors[i%colors.length],true)));
  polygon(draft,"#212121",false);
}
function objectList() {
  $("objects").replaceChildren();$("object-count").textContent=annotation.objects.length;
  annotation.objects.forEach((o,i)=>{
    const b=document.createElement("button");b.className="object"+(i===selected?" selected":"");
    b.textContent=`${i+1}. ${o.label||"Unlabeled object"}`;
    b.onclick=()=>{selected=i;objectList();fields();draw();};$("objects").append(b);
  });
}
function fields() {
  const o=annotation.objects[selected];$("fields").hidden=!o;
  if(o){$("label").value=o.label||"";$("identity").value=o.identity||"";$("ocr").value=o.ocr||"";}
}
function sampleList() {
  $("count").textContent=state.dataset.samples.length;$("samples").replaceChildren();
  state.dataset.samples.forEach(s=>{
    const b=document.createElement("button");b.className="sample"+(s.id===sample?.id?" active":"");
    const title=document.createElement("span");title.textContent=s.id;
    const detail=document.createElement("small");detail.textContent=`${s.split} \u00b7 ${s.annotation.status}`;
    b.append(title,detail);b.onclick=()=>openSample(s);$("samples").append(b);
  });
}
async function openSample(next) {
  if (busy || (dirty && !confirm("Discard unsaved annotation edits?"))) return;
  sample=next;annotation=structuredClone(next.annotation);draft=[];selected=-1;dirty=false;dragging=null;
  readOnly=annotation.objects.some(o=>"mask" in o);
  $("sample-title").textContent=sample.id;
  $("sample-info").textContent=`${sample.image.width} \u00d7 ${sample.image.height} \u00b7 ${sample.split} \u00b7 ${sample.provenance.source_type}`;
  $("reviewer").value=annotation.reviewer||"";$("checked").checked=false;
  image=null;const incoming=new Image();const id=sample.id;
  incoming.onload=()=>{if(sample.id===id){image=incoming;draw();}};
  incoming.onerror=()=>notice("Image could not load. Run dataset validation.",true);
  incoming.src="/image/"+encodeURIComponent(sample.id);
  sampleList();objectList();fields();buttons();
  notice(readOnly?"Read-only: this sample uses binary masks. Review those masks in an external mask editor; this polygon editor does not display them.":
    sample.provenance.source_type==="synthetic"?"Synthetic practice image. These labels test the software, not model quality.":"Review this owned image. Training permission is checked separately at export.");
}
function point(event) {
  const rect=$("canvas").getBoundingClientRect();
  return [Math.max(0,Math.min(sample.image.width-1,(event.clientX-rect.left)*sample.image.width/rect.width)),
          Math.max(0,Math.min(sample.image.height-1,(event.clientY-rect.top)*sample.image.height/rect.height))];
}
$("canvas").addEventListener("pointerdown",e=>{
  if(!image||busy||readOnly)return;
  const p=point(e),radius=10*sample.image.width/$("canvas").clientWidth;
  if(!draft.length&&selected>=0){
    const obj=annotation.objects[selected];
    for(const poly of obj.polygons||[])for(let i=0;i<poly.length;i++)
      if(Math.hypot(poly[i][0]-p[0],poly[i][1]-p[1])<radius){dragging={poly,index:i};$("canvas").setPointerCapture(e.pointerId);return;}
  }
  draft.push(p);changed();draw();
});
$("canvas").addEventListener("pointermove",e=>{if(dragging){dragging.poly[dragging.index]=point(e);changed();draw();}});
$("canvas").addEventListener("pointerup",()=>{dragging=null;});
$("canvas").addEventListener("pointercancel",()=>{dragging=null;});
$("finish").onclick=()=>{
  if(draft.length<3)return;
  annotation.objects.push({id:"obj_"+crypto.randomUUID().replaceAll("-",""),label:"",polygons:[draft]});
  draft=[];selected=annotation.objects.length-1;changed();objectList();fields();draw();$("label").focus();
};
$("undo").onclick=()=>{draft.pop();buttons();draw();};
$("discard").onclick=()=>{draft=[];buttons();draw();};
["label","identity","ocr"].forEach(field=>$(field).addEventListener("input",()=>{
  if(selected<0)return;const obj=annotation.objects[selected];
  if(field!=="label"&&!$(field).value)delete obj[field];else obj[field]=$(field).value;
  changed();objectList();
}));
$("remove").onclick=()=>{annotation.objects.splice(selected,1);selected=-1;changed();fields();objectList();draw();};
$("reviewer").oninput=()=>{dirty=true;buttons();};
$("checked").onchange=buttons;
async function save(status) {
  if(busy||readOnly||draft.length)return;
  if(status==="verified"&&(!$("checked").checked||!$("reviewer").value.trim()))return;
  busy=true;buttons();const sending=structuredClone(annotation);
  sending.status=status;sending.reviewer=$("reviewer").value.trim();
  try{
    const response=await fetch("/annotation",{method:"POST",headers:{"Content-Type":"application/json","X-Vision-Token":state.token},
      body:JSON.stringify({sample_id:sample.id,revision:state.revision,annotation:sending})});
    const result=await response.json();if(!response.ok)throw new Error(result.error||"Save failed");
    state.revision=result.revision;sample.annotation=result.annotation;annotation=structuredClone(result.annotation);dirty=false;
    sampleList();notice(status==="verified"?"Verified annotation saved locally. Permission checks still apply before export.":"Draft saved locally. It cannot enter a verified training export.");
  }catch(e){notice(e.message,true);}finally{busy=false;buttons();}
}
$("save-draft").onclick=()=>save("draft");$("verify").onclick=()=>save("verified");
async function load() {
  if(busy||(dirty&&!confirm("Discard unsaved edits and reload?")))return;
  try{const r=await fetch("/session");if(!r.ok)throw new Error("Unable to open dataset");
    state=await r.json();dirty=false;$("dataset-id").textContent="Dataset: "+state.dataset.id;
    await openSample(state.dataset.samples[0]);
  }catch(e){notice(e.message,true);}
}
$("reload").onclick=load;
window.addEventListener("beforeunload",e=>{if(dirty){e.preventDefault();e.returnValue="";}});
window.addEventListener("keydown",e=>{if((e.ctrlKey||e.metaKey)&&e.key==="s"){e.preventDefault();save("draft");}});
window.addEventListener("resize",draw);
load();
