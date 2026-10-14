"use client";
import { useCallback, useEffect, useRef, useState } from "react";
import { MapPin, Search, X } from "lucide-react";
import { useApiSession } from "@/lib/use-api-session";
import { userFacingError } from "@/lib/user-facing-error";
import { AskMarkdown } from "./ask-markdown";
import { useAppDialog } from "./app-dialog-provider";
import { askPhysical, candidateLabel, suggestedMemoryName, confirmPhysical, getPhysicalOptions, physicalHistory, PhysicalAnswer, PhysicalCandidate, PhysicalOptions, PhysicalSelection } from "@/lib/physical-memory";
import styles from "./physical-memory-panel.module.css";

function accessLost(reason:unknown) {
  return (typeof reason==="object"&&reason!==null&&"status" in reason&&[401,403].includes(Number(reason.status))) || (reason instanceof Error&&reason.message.includes("Your account changed"));
}

export function PhysicalMemoryPanel({teamId,initialSelection}: {teamId:string;initialSelection?:PhysicalSelection}) {
  const {accountId} = useApiSession();
  return accountId ? <PhysicalWorkspace key={`${teamId}:${accountId}:${initialSelection?.connection_id||""}:${initialSelection?.variant_gid||""}`} teamId={teamId} account={accountId} initialSelection={initialSelection}/> : null;
}
function PhysicalWorkspace({teamId,account,initialSelection}: {teamId:string;account:string;initialSelection?:PhysicalSelection}) {
  const [options,setOptions] = useState<PhysicalOptions>();
  const [question,setQuestion] = useState("");
  const [barcode,setBarcode] = useState(false);
  const [answer,setAnswer] = useState<PhysicalAnswer>();
  const [selected,setSelected] = useState<PhysicalCandidate>();
  const [error,setError] = useState("");
  const [busy,setBusy] = useState(false);
  const [editing,setEditing] = useState(false);
  const alive=useRef(true),ticket=useRef(0),optionTicket=useRef(0),pending=useRef(false),working=useRef(false);
  const initialized=useRef(false);
  const clearAccess=useCallback(()=>{
    ticket.current++;optionTicket.current++;pending.current=false;working.current=false;
    setAnswer(undefined);setSelected(undefined);setOptions(undefined);setQuestion("");setBusy(false);setEditing(false);
    setError("Your Team access changed. Reopen this Team.");
  },[]);
  const loadOptions=useCallback(async()=>{
    const request=++optionTicket.current;
    try {const value=await getPhysicalOptions(teamId,account);if(alive.current&&request===optionTicket.current)setOptions(value);}
    catch(reason){if(alive.current&&request===optionTicket.current){if(accessLost(reason))clearAccess();else setError(userFacingError(reason,"Could not load Team locations."));}}
  },[teamId,account,clearAccess]);
  useEffect(()=>{alive.current=true;void loadOptions();
    const refresh=()=>{if(document.visibilityState==="visible"&&!pending.current&&!working.current)void loadOptions();};
    const timer=setInterval(refresh,30000);window.addEventListener("focus",refresh);
    return()=>{alive.current=false;clearInterval(timer);window.removeEventListener("focus",refresh);};
  },[loadOptions]);
  const search=useCallback(async(candidate?:PhysicalCandidate|PhysicalSelection)=> {
    if(pending.current||working.current||(!question.trim()&&!candidate)) return;
    pending.current=true;setBusy(true);setError("");setAnswer(undefined);setSelected(undefined);
    const request=++ticket.current;
    try {
      const value=await askPhysical(teamId,account,candidate ? {question:"Where is this product?",...("memory_id" in candidate&&candidate.memory_id?{memory_id:candidate.memory_id}:{connection_id:candidate.connection_id!,variant_gid:candidate.variant_gid!})} : {question:question.trim(),...(barcode?{barcode:question.trim()}: {})});
      if(alive.current&&request===ticket.current) {setAnswer(value);if(value.result.candidates.length===1) setSelected(value.result.candidates[0]);}
    } catch(reason) {if(alive.current&&request===ticket.current){if(accessLost(reason))clearAccess();else setError(userFacingError(reason,"Could not check this Team's physical memory."));}}
    finally {pending.current=false;if(alive.current&&request===ticket.current) setBusy(false);}
  },[teamId,account,question,barcode,clearAccess]);
  useEffect(()=>{if(initialSelection&&!initialized.current){initialized.current=true;void search(initialSelection);}},[initialSelection,search]);
  return <section className={`team-panel ${styles.panel}`} aria-label="Team physical memory">
    <div className="team-panel-heading"><div><h2>Physical memory</h2><p>Find a product. Confirm where it belongs.</p></div><span className="status-pill">Read-only lookup</span></div>
    <form className={styles.search} onSubmit={event=>{event.preventDefault();void search();}}>
      <label htmlFor="physical-question">{barcode?"Exact barcode":"Ask this Team"}</label>
      <div><input id="physical-question" className="product-input" disabled={editing} maxLength={barcode?255:4000} value={question} onChange={event=>setQuestion(event.target.value)} placeholder={barcode?"Keep leading zeros":"Where is the black medium hoodie?"}/><button className="product-button primary" disabled={busy||editing||!question.trim()}><Search size={15}/>{busy?"Checking...":"Find"}</button></div>
      <label className={styles.barcode}><input type="checkbox" disabled={editing} checked={barcode} onChange={event=>setBarcode(event.target.checked)}/>Search by barcode</label>
    </form>
    {error&&<div className="notice-error" role="alert">{error}{!options&&<button className="product-button" onClick={()=>{setError("");void loadOptions();}}>Retry locations</button>}</div>}
    {answer&&<div aria-live="polite" className={styles.answer}><AskMarkdown>{answer.assistant_message}</AskMarkdown>{answer.answer_context.sources.length>0&&<details><summary>Sources</summary>{answer.answer_context.sources.map((source,index)=><p key={index}><strong>{source.label}</strong><br/>{source.detail}</p>)}</details>}</div>}
    {answer&&answer.result.candidates.length>1&&<div className={styles.candidates}>{answer.result.candidates.map(candidate=><button disabled={busy} className="product-card" key={candidate.memory_id||`${candidate.connection_id}:${candidate.variant_gid}`} onClick={()=>void search(candidate)}><MapPin size={18}/><span><strong>{candidateLabel(candidate)}</strong><small>SKU: {candidate.sku||"Not supplied"}</small></span></button>)}{answer.result.truncated&&<p>More matches exist. Narrow the name, size, or color.</p>}</div>}
    {selected&&options&&<LocationEditor key={selected.memory_id||`${selected.connection_id}:${selected.variant_gid}`} candidate={selected} options={options} team={teamId} account={account} barcode={barcode?question.trim():undefined} onAccessDenied={clearAccess} onWorking={value=>{working.current=value;setEditing(value);}} onSaved={memory=>search({...selected,memory_id:memory})}/>}
  </section>;
}

function LocationEditor({candidate,options,team,account,barcode,onSaved,onWorking,onAccessDenied}: {candidate:PhysicalCandidate;options:PhysicalOptions;team:string;account:string;barcode?:string;onSaved:(memory:string)=>Promise<void>;onWorking:(value:boolean)=>void;onAccessDenied:()=>void}) {
  const [name,setName]=useState(()=>suggestedMemoryName(candidate));
  const [placement,setPlacement]=useState("");
  const [space,setSpace]=useState("");
  const [bin,setBin]=useState("");
  const [count,setCount]=useState("");
  const [busy,setBusy]=useState(false),[error,setError]=useState(""),[saved,setSaved]=useState(false);
  const [history,setHistory]=useState<Awaited<ReturnType<typeof physicalHistory>>>();
  const alive=useRef(true),pending=useRef(false),attempt=useRef<{body:string;request:string}|undefined>(undefined);
  const {confirmAction}=useAppDialog();
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
  const current=candidate.placements.find(value=>value.placement_id===placement);
  const bins=options.spaces.find(value=>value.id===space)?.bins||[];
  function select(id:string) {setPlacement(id);setHistory(undefined);setSaved(false);const p=candidate.placements.find(value=>value.placement_id===id);setSpace(p?.space_id||"");setBin(p?.bin_id||"");setCount(p?.observed_count?.toString()||"");}
  async function save(remove=false) {
    if(pending.current) return;
    if(!remove&&(!name.trim()||!space||(count!==""&&(!/^\d+$/.test(count)||Number(count)>2147483647)))) {setError("Enter a name, choose a Space, and use a whole nonnegative count or leave it blank.");return;}
    pending.current=true;setBusy(true);onWorking(true);setError("");setSaved(false);
    try {
      if(remove&&!await confirmAction({title:"Remove this location?",message:"FindEZ will keep its confirmation history. This does not change inventory stock.",confirmLabel:"Remove location"})) return;
      if(!alive.current)return;
      const body={native_label:name.trim(),...(candidate.memory_id?{memory_id:candidate.memory_id}:{connection_id:candidate.connection_id,variant_gid:candidate.variant_gid,...(barcode?{barcode}: {})}),placement_id:current?.placement_id||null,expected_revision:current?.revision||0,space_id:space||null,bin_id:bin||null,observed_count:count===""?null:Number(count),action:remove?"remove":"confirm"};
      const serialized=JSON.stringify(body);
      if(attempt.current?.body!==serialized) attempt.current={body:serialized,request:crypto.randomUUID()};
      const receipt=await confirmPhysical(team,account,{...body,request_id:attempt.current.request});
      if(!receipt.observation_id) throw new Error("The confirmation was not saved.");
      if(alive.current){setSaved(true);onWorking(false);await onSaved(receipt.memory_id);}
    } catch(reason) {if(alive.current){if(accessLost(reason))onAccessDenied();else setError(userFacingError(reason,"Could not save this location. Refresh if someone else changed it."));}}
    finally {pending.current=false;if(alive.current){setBusy(false);onWorking(false);}}
  }
  return <div className={styles.editor}>
    <h3>{options.can_confirm?"Confirm a physical location":"Confirmed locations"}</h3>
    {!options.can_confirm&&<p>You have view-only access. An editor can confirm a location.</p>}
    {options.can_confirm&&<form onSubmit={event=>{event.preventDefault();void save();}}>
      <label>FindEZ name<input className="product-input" required maxLength={200} value={name} disabled={!!candidate.native_label||busy} onChange={event=>setName(event.target.value)} placeholder="Write the name you want FindEZ to remember"/></label>
      <p>Review the suggested name. This name and your location confirmation remain in FindEZ after disconnecting Shopify.</p>
      {candidate.placements.length>0&&<label>Confirmation<select className="product-select" disabled={busy} value={placement} onChange={event=>select(event.target.value)}><option value="">Add another location</option>{candidate.placements.map(p=><option key={p.placement_id} value={p.placement_id}>{p.space_name}{p.bin_name?` / ${p.bin_name}`:""}</option>)}</select></label>}
      <div className={styles.fields}><label>Space<select required className="product-select" disabled={busy} value={space} onChange={event=>{setSpace(event.target.value);setBin("");}}><option value="">Choose a Team Space</option>{options.spaces.map(value=><option key={value.id} value={value.id}>{value.name}</option>)}</select></label><label>Bin<select className="product-select" disabled={busy||!space} value={bin} onChange={event=>setBin(event.target.value)}><option value="">Space only</option>{bins.map(value=><option key={value.id} value={value.id}>{value.name}</option>)}</select></label></div>
      <label>Count observed here (optional)<input className="product-input" type="number" min="0" max="2147483647" step="1" disabled={busy} value={count} onChange={event=>setCount(event.target.value)} placeholder="Unknown if blank"/></label>
      {options.spaces.length===0&&<p>Link or create a Team Space first.</p>}
      <div className="product-actions"><button className="product-button primary" disabled={busy||!options.spaces.length}>{busy?"Saving...":"Confirm location"}</button>{current&&<button className="product-button" type="button" disabled={busy} onClick={()=>void save(true)}><X size={14}/>Remove location</button>}</div>
    </form>}
    {error&&<p className="notice-error" role="alert">{error}</p>}{saved&&<p role="status">Location confirmation saved.</p>}
    {candidate.placements.map(p=><div className={styles.record} key={p.placement_id}><strong>{p.space_name}{p.bin_name?` / ${p.bin_name}`:""}</strong><p>{p.actor_label} / {new Date(p.confirmed_at).toLocaleString()} / Revision {p.revision}</p><p>{p.observed_count===null?"No physical count recorded":`Observed count: ${p.observed_count}`}</p><button className="product-button" disabled={busy} onClick={()=>void physicalHistory(team,account,p.placement_id).then(value=>{if(alive.current)setHistory(value);}).catch(reason=>{if(alive.current){if(accessLost(reason))onAccessDenied();else setError(userFacingError(reason,"Could not load confirmation history."));}})}>History</button></div>)}
    {history&&<div className={styles.history}><h4>Confirmation history</h4><p>Up to 100 recent confirmations from Spaces still linked to this Team.</p>{history.observations.map(event=><p key={event.observation_id}>Revision {event.revision} / {event.event_type} / {event.space_label}{event.bin_label?` / ${event.bin_label}`:""}<br/>{event.actor_label} / {new Date(event.confirmed_at).toLocaleString()} / {event.observed_count===null?"No count":`Observed ${event.observed_count}`}</p>)}</div>}
  </div>;
}
