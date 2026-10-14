import { accountRequest } from "./account-request";
export type Placement = {
  placement_id: string; revision: number; space_id: string; space_name: string;
  bin_id: string | null; bin_name: string | null; observed_count: number | null;
  actor_id: string | null; actor_label: string; confirmed_at: string; source_kind: string;
};
export type PhysicalCandidate = {
  memory_id: string | null; native_label: string | null; connection_id: string | null;
  variant_gid: string | null; product_title: string | null; variant_title: string | null;
  sku: string | null; barcodes: {value: string}[] | null; catalog_deleted: boolean;
  connection_status: string; tracked: boolean | null; placements: Placement[];
  shopify_inventory: {location_name: string; quantities: Record<string,number>; synced_at: string}[];
};
export type PhysicalAnswer = {
  kind: string; assistant_message: string;
  result: {candidates: PhysicalCandidate[]; truncated: boolean};
  answer_context: {sources: {kind: string; label: string; detail: string}[]};
};
export type PhysicalOptions = { can_confirm: boolean; spaces: {id: string; name: string; bins: {id: string; name: string}[]}[] };
export type PhysicalQuery = {question: string; barcode?: string; memory_id?: string; connection_id?: string; variant_gid?: string};
function base(team: string) { return `/teams/${encodeURIComponent(team)}/physical`; }
export function getPhysicalOptions(team: string, account: string) { return accountRequest<PhysicalOptions>(account,`${base(team)}/options`); }
export function askPhysical(team: string, account: string, query: PhysicalQuery) { return accountRequest<PhysicalAnswer>(account,`${base(team)}/ask`,{method:"POST",body:query}); }
export function confirmPhysical(team: string, account: string, payload: Record<string,unknown>) { return accountRequest<{memory_id:string;placement_id:string;revision:number;observation_id:string}>(account,`${base(team)}/confirm`,{method:"POST",body:payload}); }
export function physicalHistory(team: string, account: string, placement: string) { return accountRequest<{observations: {observation_id:string;event_type:string;revision:number;observed_count:number|null;space_label:string;bin_label:string|null;actor_label:string;confirmed_at:string}[]}>(account,`${base(team)}/placements/${encodeURIComponent(placement)}/history`); }
export function candidateLabel(candidate: PhysicalCandidate) { return candidate.native_label || `${candidate.product_title || "Product"} / ${candidate.variant_title || "Variant"}`; }
