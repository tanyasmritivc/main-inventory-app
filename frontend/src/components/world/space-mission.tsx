import type { Room } from './types';

export function SpaceMission({ room, storageCount, busy, hide, play, browse, quests }: {
  room: Room; storageCount: number; busy: boolean;
  hide(): void; play(): void; browse(): void; quests(): void;
}) {
  return <aside className="world-purpose" aria-label="Your Space mission">
    <header><small>YOUR SPACE MISSION</small><button className="tb" aria-label="Hide mission" onClick={hide}>×</button></header>
    <div className="world-purpose-body">
      <h2>{room.sample ? 'Explore a sample' : 'Know your Space'}</h2>
      <p>{room.sample ? 'Look around, then choose My spaces to play with your own inventory.' : 'Learn what you own and where it lives. Find five real items, then practice remembering their places.'}</p>
      {!room.sample && room.items.length < 5 && <p className="muted">Find it unlocks when this Space has five saved items.</p>}
      <button className="btn ghost" disabled={!!room.sample || !room.items.length} onClick={browse}>Explore storage</button>
      <button className="btn ghost" onClick={quests}>Quests &amp; rewards</button>
      <p className="world-purpose-count">{room.sample ? 'Demo room' : `${room.item_count} saved items · ${storageCount} storage ${storageCount === 1 ? 'area' : 'areas'}`}</p>
    </div>
    <footer><button className="btn" disabled={busy || !!room.sample || room.items.length < 5} onClick={play}>Start Find it</button></footer>
  </aside>;
}
