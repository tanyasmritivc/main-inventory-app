"use client";

import {useCallback,useEffect,useRef,useState} from "react";
import {Check,MapPin,Search} from "lucide-react";
import {getMerchantProgress,MerchantProgress,MigrationVariant,ShopifyConnection} from "@/lib/shopify";
import {PhysicalSelection} from "@/lib/physical-memory";
import {userFacingError} from "@/lib/user-facing-error";
import styles from "./merchant-migration-guide.module.css";

function label(row:MigrationVariant) {return row.product_title+(row.variant_title==="Default Title"?"":` / ${row.variant_title}`);}
type GuideProps = {teamId:string;token:string;store:ShopifyConnection;onOpenMemory:(selection:PhysicalSelection)=>void;onOpenSpaces:()=>void};
export function MerchantMigrationGuide(props:GuideProps) {
  return <ScopedGuide key={`${props.teamId}:${props.token}:${props.store.connection_id}`} {...props}/>;
}
function ScopedGuide({teamId,token,store,onOpenMemory,onOpenSpaces}:GuideProps) {
  const [progress,setProgress]=useState<MerchantProgress>(),[error,setError]=useState("");
  const alive=useRef(true),ticket=useRef(0);
  const refresh=useCallback(async()=>{
    const request=++ticket.current;
    try {
      const next=await getMerchantProgress(teamId,store.connection_id,token);
      if(alive.current&&request===ticket.current){setProgress(next);setError("");}
    } catch(reason){if(alive.current&&request===ticket.current){setProgress(undefined);setError(userFacingError(reason,"Could not check migration progress."));}}
  },[teamId,store.connection_id,token]);
  useEffect(()=>{alive.current=true;
    const initial=window.setTimeout(()=>void refresh(),0);
    const focus=()=>{if(!document.hidden)void refresh();};
    const timer=setInterval(focus,30000);window.addEventListener("focus",focus);
    return()=>{alive.current=false;clearTimeout(initial);clearInterval(timer);window.removeEventListener("focus",focus);};
  },[refresh]);
  function open(row:MigrationVariant) {onOpenMemory({connection_id:store.connection_id,variant_gid:row.variant_gid});}
  const mapped=!!progress&&progress.confirmed_variants>0;
  const connected=progress?.connection_status==="connected";
  const fullyMapped=!!progress&&progress.import_complete&&progress.total_variants>0&&progress.confirmed_variants===progress.total_variants;
  return <section className={styles.guide} aria-label="Merchant setup">
    <header><div><h4>Set up your stockroom</h4><p>Your catalog is the starting point. Confirm where products belong.</p></div><button className="product-button" onClick={()=>void refresh()}>Check progress</button></header>
    {error&&<p className="notice-error" role="alert">{error}</p>}
    {!progress&&!error&&<p role="status">Checking catalog and location records...</p>}
    {progress&&<>
      <ol className={styles.steps}>
        <li><span className={connected?styles.done:styles.number}>{connected?<Check size={13}/>:"1"}</span><div><strong>Connect Shopify</strong><p>{connected?"Store connected.":"Cached records are available. Renew Shopify access before adding locations."}</p></div></li>
        <li><span className={progress.import_complete?styles.done:styles.number}>{progress.import_complete?<Check size={13}/>:"2"}</span><div><strong>Bring in your catalog</strong><p>{progress.total_variants} variants available.{progress.import_complete?` Last complete sync: ${new Date(progress.last_complete_sync!).toLocaleString()}.`:" The current import has not completed yet."}{progress.sync_in_progress?" Sync is in progress; available records may be incomplete.":""}</p></div></li>
        <li><span className={fullyMapped?styles.done:styles.number}>{fullyMapped?<Check size={13}/>:"3"}</span><div><strong>Confirm storage</strong><p>{progress.confirmed_variants} of {progress.total_variants} variants have an accessible confirmed location. {progress.unconfirmed_variants} still need a location.</p>{progress.older_confirmations>0&&<p>{progress.older_confirmations} variants have confirmations at least 7 days old. Recheck those locations.</p>}</div></li>
        <li><span className={styles.number}>4</span><div><strong>Try a location lookup</strong><p>{mapped?"Use a saved variant to see its location, source and confirmation time.":"Confirm one product first, then try finding it from another employee's account."}</p>{progress.confirmed_example&&<button className="product-button" onClick={()=>open(progress.confirmed_example!)}><Search size={14}/>Locate {label(progress.confirmed_example)}</button>}</div></li>
      </ol>
      {progress.total_variants===0&&<p>{progress.import_complete?"No current variants were found in the completed catalog. Add products in Shopify, then sync again.":"No variants are available yet. Wait for catalog sync before mapping storage."}</p>}
      {progress.can_confirm&&progress.space_count===0&&<div className={styles.next}><p>Add or link a Team Space such as your stockroom before confirming a location.</p><button className="product-button primary" onClick={onOpenSpaces}>Set up storage Spaces</button></div>}
      {progress.space_count>0&&progress.unconfirmed_sample.length>0&&<div className={styles.queue}><h5>Choose a product to map</h5><p>These variants have no currently accessible confirmed storage location.</p>{!progress.can_confirm&&<p>An authorized editor can confirm storage.</p>}
        {progress.unconfirmed_sample.map(row=><div key={row.variant_gid}><span><strong>{label(row)}</strong><small>SKU: {row.sku||"Not supplied"}</small></span><button className="product-button" disabled={!progress.can_confirm} onClick={()=>open(row)}><MapPin size={14}/>Confirm location</button></div>)}
        {progress.unconfirmed_variants>progress.unconfirmed_sample.length&&<p>Showing the first {progress.unconfirmed_sample.length}. Check progress after saving to see the next products.</p>}
      </div>}
      <p className={styles.note}>Catalog images and stock records do not confirm a physical location. Nothing is saved until you confirm it.</p>
    </>}
  </section>;
}
