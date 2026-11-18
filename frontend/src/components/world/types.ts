export type Position = { x: number; z: number; r: number; y: number };
export type Piece = Position & { id: string; t: string };
export type Layout = { v: 2; floor: number; pieces: Piece[]; places: Record<string, Position> };
export type WorldItem = {
  id: string; name: string; quantity?: number | null; category?: string | null;
  photo?: string | null; space_id?: string; location?: string; bin_id?: string | null;
  bin?: string | null; area_id?: string | null; container?: string | null; running_low?: boolean;
};
export type StorageArea = { id: string; name: string; kind: string; parent_id?: string | null };
export type Room = {
  id: string; name: string; inventory_id?: string; organization_id?: string | null;
  can_edit: boolean; items: WorldItem[]; bins: { id: string; name: string }[];
  storage_areas: StorageArea[]; layout: Layout | null; revision: number;
  item_count: number; capped: boolean; sample?: string; public?: boolean;
  storage?: { id: string; kind: string; name?: string }[];
};
export type Quest = { id: string; title: string; event: string; goal: number; xp: number; progress: number; claimed: boolean };
export type Progress = {
  xp: number; level: number; xp_to_next_level: number; lifetime_xp: number;
  lifetime_rank: number; best_level: number; streak: number; tour_done: boolean;
  season: { id: string; name: string }; quests: Quest[];
  unlocks: { pieces: string[]; styles: number[] };
  rules: { levels: number[]; locks: Record<string, number>; styles: number[]; xp: Record<string, number>; caps: Record<string, number> };
};
export type Award = {
  gained: number; xp: number; level: number; leveled_up: boolean;
  new_unlocks: { pieces: string[]; styles: number[] }; quests_completed: string[];
};
export type Daily = { scope_id: string; day: string; available: boolean; score: number | null; targets: { id: string; name: string; space_id: string; location: string }[] };
export type Share = { id: string; space_id: string; token: string; revoked_at: string | null; show_counts: boolean; show_locations: boolean; show_photos: boolean };
export type SceneSelection = { id: string; kind: 'piece' | 'item' | 'area' | 'bin'; name: string; t?: string } | null;
export type SceneCatalog = {
  pieces: { id: string; name: string; category: string; image: string }[];
  themes: { id: number; name: string; image: string; level: number }[];
  categories: [string, string][]; bolt: string;
  samples: { id: string; name: string }[];
};
export type Scene = {
  load(room: Room, layout: Layout): void;
  setMode(build: boolean): void;
  focusItems(ids: string[], storageKey: string | null): void;
  setPlacing(type: string | null): void;
  rotate(direction: number): void;
  duplicate(): void; remove(): void; undo(): void; redo(): void;
  setFloor(index: number): void; clearScan(): void; scan(id: string): void;
  pop(id: string): void;
  setMuted(value: boolean): void; dispose(): void;
};
