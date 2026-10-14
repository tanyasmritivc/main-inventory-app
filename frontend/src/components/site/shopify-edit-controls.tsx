"use client";

import {useEffect,useRef,useState} from "react";
import {useAppDialog} from "./app-dialog-provider";
import {userFacingError} from "@/lib/user-facing-error";
import {ShopifyAccessResult,ShopifyConnection,ShopifyEdit,ShopifyVariant,saveShopifyPermissions,refreshShopifyPermissions,prepareShopifyEdit,executeShopifyEdit,getShopifyEdit,getShopifyEdits,reviewUnknownShopifyEdit} from "@/lib/shopify";
import styles from "./shopify-panel.module.css";

export function ShopifyPermissionsForm({teamId,token,store,onChanged,onAuthorize,editsEnabled}:{teamId:string;token:string;store:ShopifyConnection;onChanged:()=>Promise<void>;onAuthorize:()=>void;editsEnabled:boolean}) {
  const [products,setProducts]=useState(!!store.edit_products),[inventory,setInventory]=useState(!!store.edit_inventory);
  const [access,setAccess]=useState<"owner"|"editors">(store.edit_access||"owner");
  const [busy,setBusy]=useState(false),[error,setError]=useState("");
  const [result,setResult]=useState<ShopifyAccessResult>();
  const pending=useRef(false),alive=useRef(true);
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
  const {confirmAction}=useAppDialog();
  const needsApproval=result?.needs_authorization || (store.edit_products&&!store.granted_scopes?.includes("write_products")) || (store.edit_inventory&&!store.granted_scopes?.includes("write_inventory"));
  const revokePending=result?.revocation_pending || (!store.edit_products&&store.granted_scopes?.includes("write_products")) || (!store.edit_inventory&&store.granted_scopes?.includes("write_inventory"));
  async function save(refreshOnly=false) {
    if(pending.current)return;
    pending.current=true;setBusy(true);setError("");setResult(undefined);
    try {
      if(!refreshOnly) {
        const ok=await confirmAction({title:"Change Shopify permissions?",message:`Product details: ${products?"read and edit":"read only"}. Stock: ${inventory?"read and edit":"read only"}. ${access==="owner"?"Only you can edit.":"Team mentors and members can edit; viewers cannot."} Shopify must approve any new edit scopes.`,confirmLabel:"Save permissions"});
        if(!ok||!alive.current)return;
      }
      const next=refreshOnly?await refreshShopifyPermissions(teamId,store.connection_id,token):await saveShopifyPermissions(teamId,store.connection_id,token,{edit_products:products,edit_inventory:inventory,edit_access:access,expected_revision:store.permission_revision||0});
      if(!refreshOnly&&!next.saved)throw new Error("Permissions were not saved.");
      if(alive.current){setResult(next);await onChanged();}
    } catch(reason){if(alive.current)setError(userFacingError(reason,"Could not update Shopify permissions."));}
    finally {pending.current=false;if(alive.current)setBusy(false);}
  }
  return <details className={styles.permissions}><summary>Connection permissions</summary>
    <p>Products and stock can be viewed by this Team. Choose the edits FindEZ may perform.</p>
    <form onSubmit={event=>{event.preventDefault();void save();}}>
      <label><input type="checkbox" disabled={busy||(!editsEnabled&&!products)} checked={products} onChange={event=>setProducts(event.target.checked)}/>Allow product detail edits</label>
      <label><input type="checkbox" disabled={busy||(!editsEnabled&&!inventory)} checked={inventory} onChange={event=>setInventory(event.target.checked)}/>Allow stock adjustments</label>
      <label>Who can edit<select className="product-select" disabled={busy} value={access} onChange={event=>setAccess(event.target.value as "owner"|"editors")}><option value="owner">Owner only</option><option value="editors">Team mentors and members</option></select></label>
      {!editsEnabled&&<p>Edits are not enabled for this installation. You can still turn existing edit permissions off.</p>}
      <div className="product-actions"><button className="product-button" disabled={busy}>{busy?"Saving...":"Save permissions"}</button><button type="button" className="product-button" disabled={busy} onClick={()=>void save(true)}>Check Shopify access</button></div>
    </form>
    {error&&<p className="notice-error" role="alert">{error}</p>}
    {result?.saved&&<p role="status">Owner permissions saved.</p>}
    {needsApproval&&<p>Shopify approval is still required. <button className="product-button" disabled={busy} onClick={onAuthorize}>Approve in Shopify</button></p>}
    {revokePending&&<p role="alert">FindEZ uses your saved restrictions. Shopify has not confirmed removal of its previous grant. Check access again or review the app permissions in Shopify.</p>}
  </details>;
}

export function ShopifyEditHistory({teamId,token,store}:{teamId:string;token:string;store:ShopifyConnection}) {
  const [rows,setRows]=useState<ShopifyEdit[]>([]),[busy,setBusy]=useState(false),[error,setError]=useState("");
  const alive=useRef(true),pending=useRef(false);
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
  const {confirmAction}=useAppDialog();
  async function load() {const result=await getShopifyEdits(teamId,store.connection_id,token);if(alive.current)setRows(result.operations);}
  async function run(task:()=>Promise<void>) {
    if(pending.current)return;pending.current=true;setBusy(true);setError("");
    try{await task();}catch(reason){if(alive.current)setError(userFacingError(reason,"Could not check Shopify edit history."));}
    finally{pending.current=false;if(alive.current)setBusy(false);}
  }
  return <details className={styles.permissions}><summary>Recent Shopify edits</summary><p>Recent actions and unresolved results. Uncertain writes pause new edits until you check Shopify.</p>
    <button className="product-button" disabled={busy} onClick={()=>void run(load)}>{busy?"Checking...":"Check edit history"}</button>
    {error&&<p role="alert" className="notice-error">{error}</p>}
    {rows.map(row=><div className={styles.editor} key={row.operation_id}><strong>{row.kind==="product"?"Product details":"Stock adjustment"}</strong><p>{row.state} / {row.created_at?new Date(row.created_at).toLocaleString():""}</p><p>{row.snapshot.title||row.snapshot.variant_title}{row.snapshot.location_name?` / ${row.snapshot.location_name}`:""}{row.kind==="inventory"?` / Adjustment ${row.intent.delta}`:""}</p>
      {row.kind==="product"&&<p>{Object.entries(row.intent.changes||{}).map(([field,value])=>`${field}: ${String(value)}`).join("; ")}</p>}
      {row.reviewed_at?<p>You acknowledged checking this in Shopify. FindEZ still does not claim a verified outcome.</p>:(row.state==="unknown"||row.state==="sending")&&<button className="product-button" disabled={busy} onClick={()=>void run(async()=>{
        const approved=await confirmAction({title:"Have you checked the actual Shopify history?",message:"Confirm only after checking this product or stock adjustment in Shopify. This permits a new reviewed change but does not mark the previous action successful.",confirmLabel:"I checked Shopify"});
        if(!approved||!alive.current)return;const result=await reviewUnknownShopifyEdit(teamId,store.connection_id,token,row.operation_id);if(!result.reviewed)throw new Error("This review was not recorded.");await load();
      })}>Acknowledge Shopify check</button>}
    </div>)}
  </details>;
}

const fieldLabels={title:"Title",vendor:"Vendor",productType:"Product type",tags:"Tags"};
type ProductField=keyof typeof fieldLabels;
export function ShopifyVariantEdits({teamId,token,store,variant,onChanged}:{teamId:string;token:string;store:ShopifyConnection;variant:ShopifyVariant;onChanged:()=>Promise<void>}) {
  const [kind,setKind]=useState<"product"|"inventory">(),[field,setField]=useState<ProductField>("title"),[value,setValue]=useState(variant.product_title);
  const [location,setLocation]=useState(""),[delta,setDelta]=useState("");
  const [edit,setEdit]=useState<ShopifyEdit>(),[busy,setBusy]=useState(false),[error,setError]=useState("");
  const pending=useRef(false),alive=useRef(true);
  useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
  const {confirmAction}=useAppDialog();
  async function run(task:()=>Promise<void>) {
    if(pending.current)return;
    pending.current=true;setBusy(true);setError("");
    try{await task();}catch(reason){if(alive.current)setError(userFacingError(reason,"Could not verify this Shopify change."));}
    finally{pending.current=false;if(alive.current)setBusy(false);}
  }
  function start(next:"product"|"inventory") {setKind(next);setEdit(undefined);setError("");}
  async function prepare() {
    if(kind==="inventory"&&(!location||!/^[-+]?\d+$/.test(delta)||!Number(delta)||Math.abs(Number(delta))>1000000)) {setError("Choose a location and a whole nonzero adjustment.");return;}
    if(kind==="product"&&field==="title"&&!value.trim()){setError("Enter a product title.");return;}
    await run(async()=>{
      const body=kind==="product"?{kind:"product" as const,variant_gid:variant.variant_gid,changes:{[field]:field==="tags"?value.split(",").map(tag=>tag.trim()).filter(Boolean):value.trim()}}:{kind:"inventory" as const,variant_gid:variant.variant_gid,location_gid:location,delta:Number(delta)};
      const next=await prepareShopifyEdit(teamId,store.connection_id,token,body);
      if(!next.operation_id||next.state!=="prepared")throw new Error("A review was not prepared.");
      if(alive.current)setEdit(next);
    });
  }
  async function execute() {
    if(!edit)return;
    await run(async()=>{
      const approved=await confirmAction({title:"Apply this change in Shopify?",message:"This changes your live Shopify store. Apply only the change shown in the review.",confirmLabel:"Apply in Shopify"});
      if(!approved||!alive.current)return;
      const next=await executeShopifyEdit(teamId,store.connection_id,token,edit.operation_id);
      if(alive.current){setEdit(next);if(next.state==="succeeded")await onChanged();}
    });
  }
  const locked=busy||!!edit;
  return <div className={styles.edits}>
    {!kind&&<div className="product-actions">{store.can_edit_products&&<button className="product-button" disabled={busy} onClick={()=>start("product")}>Edit product details</button>}{store.can_edit_inventory&&variant.tracked&&<button className="product-button" disabled={busy} onClick={()=>start("inventory")}>Adjust Shopify stock</button>}</div>}
    {kind&&<div className={styles.editor} aria-label={kind==="product"?"Shopify product editor":"Shopify stock editor"}>
      <h5>{kind==="product"?"Product details":"Stock adjustment"}</h5>
      {!edit&&<form onSubmit={event=>{event.preventDefault();void prepare();}}>
        {kind==="product"?<><p>Changes apply to this Shopify product and all its variants.</p><label>Detail<select className="product-select" disabled={locked} value={field} onChange={event=>{const next=event.target.value as ProductField;setField(next);setValue(next==="title"?variant.product_title:"");}}>{Object.entries(fieldLabels).map(([name,label])=><option key={name} value={name}>{label}</option>)}</select></label><label>{fieldLabels[field]}<input className="product-input" disabled={locked} maxLength={field==="tags"?3000:200} value={value} onChange={event=>setValue(event.target.value)} placeholder={field==="tags"?"Separate tags with commas":""}/></label></>:<><p>Adjust available Shopify stock by a signed amount. A physical count stays separate.</p><label>Shopify location<select className="product-select" disabled={locked} value={location} onChange={event=>setLocation(event.target.value)}><option value="">Choose a stock location</option>{variant.shopify_inventory.filter(level=>level.location_active).map(level=><option key={level.location_gid} value={level.location_gid}>{level.location_name}</option>)}</select></label><label>Adjustment<input className="product-input" disabled={locked} inputMode="text" value={delta} onChange={event=>setDelta(event.target.value)} placeholder="For example +2 or -1"/></label></>}
        <button className="product-button" disabled={busy}>{busy?"Checking...":"Review change"}</button>
      </form>}
      {edit&&<div aria-live="polite">
        <p>Checked Shopify at {new Date(edit.snapshot.checked_at).toLocaleString()}.</p>
        {edit.kind==="inventory"?<p>{edit.snapshot.location_name}: {edit.snapshot.available} available at review. Adjustment: {edit.intent.delta!>0?"+":""}{edit.intent.delta}. Other store activity can change the current total.</p>:Object.entries(edit.intent.changes||{}).map(([name,next])=><p key={name}><strong>{fieldLabels[name as ProductField]}</strong><br/>Current: {String(edit.snapshot[name as keyof typeof edit.snapshot]??"")||"Empty"}<br/>Requested: {String(next)||"Empty"}</p>)}
        {edit.state==="prepared"&&<button className="product-button primary" disabled={busy} onClick={()=>void execute()}>{busy?"Applying...":"Apply in Shopify"}</button>}
        {edit.state==="succeeded"&&<p role="status">Shopify confirmed the change. Catalog sync is queued.</p>}
        {edit.state==="failed"&&<p role="alert">Shopify rejected this change. Review the store before preparing another edit.</p>}
        {(edit.state==="unknown"||edit.state==="sending")&&<p role="alert">The outcome is not confirmed. Check Shopify before making another change.</p>}
        <button className="product-button" disabled={busy} onClick={()=>void run(async()=>{const next=await getShopifyEdit(teamId,store.connection_id,token,edit.operation_id);if(alive.current)setEdit(next);})}>Check recorded result</button>
      </div>}
      {error&&<p role="alert" className="notice-error">{error}{edit&&" Check the recorded result before applying again."}</p>}
      <button className="product-button" disabled={busy} onClick={()=>{setKind(undefined);setEdit(undefined);setError("");}}>Close editor</button>
    </div>}
  </div>;
}
