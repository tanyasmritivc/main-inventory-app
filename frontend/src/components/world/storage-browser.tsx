'use client';
import { useEffect, useMemo, useRef, useState } from 'react';
import { CONTENTS_PAGE_SIZE, type StorageGroup } from './storage-groups';
import type { WorldItem } from './types';

export function StorageBrowser({ group, capped, playing, embedded = false, onPage, onItem, close }: {
  group: StorageGroup; capped: boolean; playing: boolean; embedded?: boolean;
  onPage(ids: string[], key: string): void; onItem(item: WorldItem): void; close(): void;
}) {
  const [filterOpen, setFilterOpen] = useState(false);
  const [query, setQuery] = useState(''), [category, setCategory] = useState(''), [page, setPage] = useState(0);
  const body = useRef<HTMLDivElement>(null);
  const categories = [...new Set(group.items.map(i => i.category).filter((c): c is string => !!c))].sort();
  const matches = useMemo(() => group.items.filter(i => (!category || i.category === category) &&
    i.name.toLocaleLowerCase().includes(query.toLocaleLowerCase().trim())), [group.items, query, category]);
  const pageCount = Math.max(1, Math.ceil(matches.length / CONTENTS_PAGE_SIZE));
  const currentPage = Math.min(page, pageCount - 1);
  const items = useMemo(() => matches.slice(currentPage * CONTENTS_PAGE_SIZE, (currentPage + 1) * CONTENTS_PAGE_SIZE), [matches, currentPage]);
  useEffect(() => { onPage(items.map(i => i.id), group.key); }, [items, group.key, onPage]);
  useEffect(() => { if (body.current) body.current.scrollTop = 0; }, [currentPage]);
  const filters = <><label className="world-contents-search">Search contents<input value={query} onChange={e => { setQuery(e.target.value); setPage(0); }} placeholder="Item name" /></label>
    {categories.length > 1 && <label className="world-contents-search">Category<select value={category} onChange={e => { setCategory(e.target.value); setPage(0); }}><option value="">All categories</option>{categories.map(c => <option key={c}>{c}</option>)}</select></label>}</>;
  return <aside className="world-contents" aria-label={`${group.name} contents`}>
    <div className="world-contents-heading"><div><small>{embedded ? `${matches.length}${capped ? '+' : ''} items` : group.kind}</small><h2>{group.name}</h2></div>{embedded && <button className="tb" aria-expanded={filterOpen} onClick={() => setFilterOpen(!filterOpen)}>Filter{query || category ? ' •' : ''}</button>}<button className="tb" aria-label="Close contents" onClick={close}>×</button></div>
    <div className="world-contents-body" ref={body}>
      {!embedded && <><p>{group.items.length}{capped ? '+' : ''} item records{playing ? ' · Tap the item you are looking for.' : ' · Select an item to see it in the room.'}</p>
      {group.key === 'unplaced' && <p className="muted">These items belong to this Space but have no bin or storage area assigned.</p>}</>}
      {(!embedded || filterOpen) && filters}
      {(!embedded || !filterOpen) && <div className="world-contents-items">{items.map(item => <button className="world-content-item" key={item.id} onClick={() => onItem(item)}><b>{item.name}</b><span>{item.category || 'Item'}{item.quantity != null ? ` · Qty ${item.quantity}` : ''}</span></button>)}</div>}
      {!items.length && <p>{group.items.length ? 'No matching items.' : 'Nothing stored here yet.'}</p>}
    </div>
    <nav className="world-contents-pages" aria-label="Contents pages"><button className="tb" disabled={currentPage === 0} onClick={() => setPage(currentPage - 1)}>Previous</button><span>{currentPage + 1} / {pageCount}</span><button className="tb" disabled={currentPage + 1 >= pageCount} onClick={() => setPage(currentPage + 1)}>Next</button></nav>
  </aside>;
}
