import type { Layout, Scene, SceneCatalog, SceneSelection, WorldItem } from './types';
export type ScanFrame = { phase: number; x: number; y: number; box: { left: number; top: number; width: number; height: number }; brackets: boolean };
export type Destination = { kind: 'bin' | 'area'; id: string; name: string } | null;
export type SceneCallbacks = {
  onReady(catalog: SceneCatalog): void;
  onStorage(key: string): void;
  onScan(item: WorldItem): void;
  onScanFrame(frame: ScanFrame | null): void;
  onSelect(selection: SceneSelection): void;
  onLayout(layout: Layout, added: string[]): void;
  onMove(item: WorldItem, destination: Destination, layout: Layout, previous: Layout): void;
  onTap(item: WorldItem): boolean;
  onError(message: string): void;
};
export function createWorldScene(root: HTMLElement, callbacks: SceneCallbacks): Scene;
