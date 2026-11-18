'use client';
/* eslint-disable @next/next/no-img-element -- Renderer thumbnails and inventory stickers are generated at runtime. */
import { useCallback, useEffect, useRef, useState, useMemo, type CSSProperties } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { accountRequest } from '@/lib/account-request';
import { privateImageSrc } from '@/lib/private-image';
import { reconcileLayout, placeLine } from './layout';
import { LayoutWriter } from './layout-writer';
import { quizQuestions, type Question } from './games';
import { ItemForm, placementBody } from './item-form';
import { SharePanel } from './share-panel';
import { storageGroups } from './storage-groups';
import { StorageBrowser } from './storage-browser';
import { StorageForm } from './storage-form';
import { WorldDialog } from './world-dialog';
import { SpaceMission } from './space-mission';
import './world-mobile.css';
import type { SceneCallbacks, ScanFrame, Destination } from './scene';
import type { Award, Daily, Layout, Progress, Room, Scene, SceneCatalog, SceneSelection, WorldItem } from './types';

type PublicRoom = Pick<Room, 'name' | 'layout' | 'items' | 'capped' | 'storage'>;
type Panel = 'menu' | 'spaces' | 'browse' | 'storage' | 'level' | 'quests' | 'add' | 'games' | 'daily' | 'quiz' | 'result' | 'share' | 'levelup' | 'search' | null;
type Quiz = { spaceId: string; spaceName: string; game: 'count' | 'where'; questions: Question[]; index: number; right: number; chosen: string | null; ref: string };
type Race = { data: Daily; index: number; started: number; penalty: number };
type Move = { item: WorldItem; destination: Destination; layout: Layout; previous: Layout };
const TOUR = [
  ["Hi, I'm Bolt", "Welcome to FindEZ World. Every room is one of your spaces, and everything you own lives inside it. I'll show you around."],
  ['Tap to scan', 'Tap anything in the room to see how FIND sees it. Each new real item you scan earns 10 XP, up to your daily scan limit.'],
  ['Add your stuff', 'Add something you actually own. It drops into its room and earns 25 XP. Give it a storage area for another 10 XP.'],
  ['Level up', 'XP levels you up. Each level unlocks new pieces for Build, like plants, a 3D printer and a robot arm.'],
  ['Quests', 'Not sure what to do next? Quests tell you. Finish one, then collect the XP.'],
  ['Play', 'Three games with three sets of rules: race to find things, guess how many you have, or pick where something lives.'],
  ['Build', 'Decorate your space. Drag things around, turn them, copy them, and undo anything. Moving an item to different storage asks you first.'],
  ["You're all set", "Start with a quest. I'll pop up with tips while you play."],
];
const emptyLayout = (): Layout => ({ v: 2, floor: 0, pieces: [], places: {} });
function publicRoom(data: PublicRoom): Room {
  const layout = data.layout || emptyLayout();
  return { ...data, id: 'shared', can_edit: false, public: true, bins: [], storage_areas: [], revision: 0, item_count: data.items.length,
    layout: { ...layout, pieces: layout.pieces.map((p, i) => ({ ...p, id: `decor-${i}` })) } };
}
function message(error: unknown) { return error instanceof Error ? error.message : 'World could not complete that action. Please try again.'; }

export function WorldClient({ accountId, embedded, publicData }: { accountId?: string; embedded: boolean; publicData?: PublicRoom }) {
  const compact = !publicData || embedded;
  const router = useRouter();
  const root = useRef<HTMLDivElement>(null), scene = useRef<Scene | null>(null), writer = useRef<LayoutWriter | null>(null);
  const alive = useRef(true), current = useRef<Room | null>(null), layout = useRef<Layout>(emptyLayout()), callbacks = useRef<SceneCallbacks | null>(null);
  const raceRef = useRef<Race | null>(null), busyRef = useRef(false), loaded = useRef(false), pendingBuild = useRef(new Set<string>()), tourShown = useRef(false);
  const [rooms, setRooms] = useState<Room[]>(publicData ? [publicRoom(publicData)] : []);
  const [selected, setSelected] = useState<Room | null>(null), [catalog, setCatalog] = useState<SceneCatalog | null>(null), [progress, setProgress] = useState<Progress | null>(null);
  const [loading, setLoading] = useState(!publicData), [error, setError] = useState(''), [saveState, setSaveState] = useState(''), [busy, setBusy] = useState(false);
  const [panel, setPanel] = useState<Panel>(null), [mode, setMode] = useState<'explore' | 'build'>('explore'), [samples, setSamples] = useState(false);
  const [scan, setScan] = useState<WorldItem | null>(null), [scanFrame, setScanFrame] = useState<ScanFrame | null>(null), [selection, setSelection] = useState<SceneSelection>(null);
  const [category, setCategory] = useState('furniture'), [styles, setStyles] = useState(false), [placing, setPlacing] = useState<string | null>(null), [muted, setMuted] = useState(false);
  const [bolt, setBolt] = useState(''), [xp, setXp] = useState<{ amount: number; key: number } | null>(null), [levelAward, setLevelAward] = useState<Award | null>(null);
  const [tour, setTour] = useState<number | null>(null), [move, setMove] = useState<Move | null>(null), [undoMove, setUndoMove] = useState<(() => Promise<void>) | null>(null);
  const [daily, setDaily] = useState<Daily | null>(null), [board, setBoard] = useState<{ name: string; seconds: number; you: boolean }[]>([]);
  const [race, setRace] = useState<Race | null>(null), [elapsed, setElapsed] = useState(0), [wrong, setWrong] = useState(0), [quiz, setQuiz] = useState<Quiz | null>(null);
  const [result, setResult] = useState<{ title: string; text: string; seconds?: number; retry?: () => Promise<void> } | null>(null), [query, setQuery] = useState('');

  const [contents, setContents] = useState<string | null>(null);
  const [guideHidden, setGuideHidden] = useState(false);
  const groups = useMemo(() => selected ? storageGroups(selected) : [], [selected]);
  const contentsGroup = groups.find(g => g.key === contents);
  const showContentsPage = useCallback((ids: string[], key: string) => { scene.current?.focusItems(ids, key); }, []);

  const request = useCallback(<T,>(path: string, body?: Record<string, unknown>, method = 'POST'): Promise<T> => {
    if (!accountId) return Promise.reject(new Error('Sign in to change your World.'));
    return accountRequest<T>(accountId, path, body === undefined ? {} : { method, body: body });
  }, [accountId]);
  const close = useCallback(() => { setPanel(null); }, []);
  const dismiss = useCallback(() => { if (!busyRef.current) setPanel(null); }, []);
  const fail = useCallback((failure: unknown) => { if (alive.current) setError(message(failure)); }, []);
  const run = useCallback(async (action: () => Promise<void>) => {
    if (busyRef.current) return;
    busyRef.current = true; setBusy(true); setError('');
    try { await action(); } catch (e) { fail(e); } finally { busyRef.current = false; if (alive.current) setBusy(false); }
  }, [fail]);
  const refreshProgress = useCallback(async () => {
    const value = await request<Progress>('/world/me'); if (alive.current) setProgress(value); return value;
  }, [request]);
  const showAward = useCallback(async (award: Award) => {
    if (!alive.current) return;
    if (award.gained) setXp({ amount: award.gained, key: Date.now() });
    if (award.leveled_up) { setLevelAward(award); setPanel('levelup'); setBolt(`Level ${award.level}! Your new pieces are ready in Build.`); }
    else if (award.quests_completed?.length) setBolt('Quest done! Collect your XP in Quests.');
    await refreshProgress();
  }, [refreshProgress]);
  const award = useCallback(async (kind: string, ref: string, value?: object) => {
    const response = await request<Award>('/world/events', { kind, ref, ...(value ? { value } : {}) }); await showAward(response);
  }, [request, showAward]);
  const flushBuild = useCallback(async () => {
    for (const id of [...pendingBuild.current]) { await award('build', id); pendingBuild.current.delete(id); }
  }, [award]);

  const activate = useCallback(async (room: Room, force = false) => {
    if (raceRef.current && current.current?.id !== room.id) throw new Error('End this round before changing Spaces.');
    if (!force) await writer.current?.flush();
    if (!alive.current) return;
    if (current.current?.id !== room.id) { setQuiz(null); setDaily(null); setBoard([]); setResult(null); }
    writer.current?.dispose(); writer.current = null;
    current.current = room; layout.current = reconcileLayout(room); loaded.current = true;
    setSelected(room); setGuideHidden(false); setContents(null); setScan(null); setScanFrame(null); setSelection(null); setPlacing(null); setSaveState(''); setUndoMove(null);
    const renderRoom = { ...room, items: room.items.map(item => ({ ...item, photo: room.public ? item.photo : privateImageSrc(item.photo, accountId) })) };
    scene.current?.load(renderRoom, layout.current); scene.current?.setMode(false); setMode('explore');
    if (room.can_edit && !room.sample && !room.public) {
      const instance = new LayoutWriter(room.revision, async (next, revision) => {
        const response = await request<{ revision: number }>('/world/layouts/' + room.id, { layout: next, revision }, 'PUT');
        room.revision = response.revision; room.layout = structuredClone(next);
        return response;
      }, state => {
        if (!alive.current || current.current?.id !== room.id) return;
        setSaveState(state);
        if (state === 'error') setError('Your layout could not be saved. It may have changed in another window. Reload World before making more changes.');
        if (state === 'saved') void flushBuild().catch(fail);
      });
      writer.current = instance;
      if (JSON.stringify(room.layout) !== JSON.stringify(layout.current)) instance.queue(layout.current);
    }
  }, [accountId, fail, flushBuild, request]);
  const refreshRooms = useCallback(async (selectId?: string) => {
    const response = await request<{ spaces: Room[]; scopes: string[] }>('/world/spaces');
    if (!alive.current) return;
    setRooms(response.spaces);
    const next = response.spaces.find(r => r.id === (selectId || current.current?.id));
    if (next) await activate(next);
    return response.spaces;
  }, [request, activate]);

  useEffect(() => {
    alive.current = true;
    let cancelled = false;
    if (!publicData) {
      Promise.all([request<{ spaces: Room[]; scopes: string[] }>('/world/spaces'), request<Progress>('/world/me')]).then(([data, me]) => {
        if (cancelled) return; setRooms(data.spaces); setProgress(me); setLoading(false); setSamples(!data.spaces.length);
      }).catch(e => { if (!cancelled) { setLoading(false); fail(e); } });
    }
    return () => { cancelled = true; alive.current = false; writer.current?.dispose(); };
  }, [request, publicData, fail]);
  useEffect(() => {
    let cancelled = false;
    import('./scene').then(module => {
      if (cancelled || !root.current) return;
      scene.current = module.createWorldScene(root.current, {
        onReady: value => { setCatalog(value); setCategory(value.categories[0]?.[0] || 'furniture'); },
        onScan: item => callbacks.current?.onScan(item), onScanFrame: frame => callbacks.current?.onScanFrame(frame),
        onStorage: key => callbacks.current?.onStorage(key),
        onSelect: value => callbacks.current?.onSelect(value), onLayout: (value, added) => callbacks.current?.onLayout(value, added),
        onMove: (...args) => callbacks.current?.onMove(...args), onTap: item => callbacks.current?.onTap(item) ?? true, onError: fail,
      });
    }).catch(fail);
    return () => { cancelled = true; scene.current?.dispose(); scene.current = null; loaded.current = false; };
  }, [fail]);
  useEffect(() => {
    if (!catalog || loading || loaded.current) return;
    const room = rooms[0] || { id: 'sample:' + catalog.samples[0].id, name: catalog.samples[0].name, sample: catalog.samples[0].id, items: [], bins: [], storage_areas: [], can_edit: false, revision: 0, layout: null, item_count: 0, capped: false };
    void activate(room).catch(fail);
  }, [catalog, loading, rooms, activate, fail]);
  useEffect(() => {
    if (catalog && progress && !progress.tour_done && !tourShown.current) { tourShown.current = true; setTour(0); }
  }, [catalog, progress]);
  useEffect(() => {
    const timer = setTimeout(() => setBolt(''), 5200); return () => clearTimeout(timer);
  }, [bolt]);
  useEffect(() => { const timer = setTimeout(() => setXp(null), 1500); return () => clearTimeout(timer); }, [xp]);
  useEffect(() => {
    const protect = (event: BeforeUnloadEvent) => { if (saveState === 'saving' || busyRef.current || move) { event.preventDefault(); event.returnValue = ''; } };
    window.addEventListener('beforeunload', protect); return () => window.removeEventListener('beforeunload', protect);
  }, [saveState, move]);
  useEffect(() => {
    if (!race) return;
    const tick = () => setElapsed((performance.now() - race.started) / 1000 + race.penalty);
    tick(); const timer = setInterval(tick, 100); return () => clearInterval(timer);
  }, [race]);

  const loadDaily = useCallback(async () => {
    const room = current.current;
    if (!room || room.sample || room.public) { setBolt('Choose one of your Spaces to play Find it.'); return; }
    setPanel('daily'); setDaily(null); setBoard([]);
    const value = await request<Daily>('/world/daily?scope_id=' + room.id);
    if (value.scope_id !== room.id) throw new Error('This round does not belong to the open Space. Please try again.');
    const scores = await request<{ scores: typeof board }>('/world/daily/leaderboard?scope_id=' + room.id);
    if (alive.current && current.current?.id === room.id) { setDaily(value); setBoard(scores.scores); }
  }, [request]);
  const finishRace = useCallback(async (finished: Race) => {
    const seconds = Math.min(3600, Math.max(2, (performance.now() - finished.started) / 1000 + finished.penalty));
    raceRef.current = null; setRace(null);
    const submit = async () => {
      const response = await request<Award>('/world/daily/score', { scope_id: finished.data.scope_id, seconds });
      setDaily({ ...finished.data, score: seconds });
      setResult({ title: 'Found all five!', text: compact ? `${seconds.toFixed(1)} seconds. You found five items in ${current.current?.name || 'this Space'}. Practice Where is it next to remember their locations.` : `${seconds.toFixed(1)} seconds`, seconds }); setPanel('result');
      await showAward(response);
    };
    try { await submit(); } catch (e) { fail(e); setResult({ title: 'Round complete', text: `${seconds.toFixed(1)} seconds. Your score has not been confirmed yet.`, retry: submit }); setPanel('result'); }
  }, [request, showAward, fail, compact]);
  useEffect(() => {
    callbacks.current = {
      onStorage: key => { if (!panel && !move && tour === null) { setScan(null); setContents(key); } },
      onReady: setCatalog, onScanFrame: setScanFrame, onSelect: setSelection, onError: fail,
      onScan: item => { setContents(null); setScan(item); setPanel(null); if (accountId && !current.current?.sample && !current.current?.public) void award('scan', item.id).catch(fail); },
      onLayout: (value, added) => { layout.current = value; const present = new Set(value.pieces.map(p => p.id)); for (const id of pendingBuild.current) if (!present.has(id)) pendingBuild.current.delete(id); added.forEach(id => pendingBuild.current.add(id)); writer.current?.queue(value); setPlacing(null); },
      onMove: (item, destination, value, previous) => { setMove({ item, destination, layout: value, previous }); scene.current?.setMode(false); },
      onTap: item => {
        if (panel || move || (tour !== null && tour !== 1)) return false;
        const active = raceRef.current;
        if (!active) { if (tour === 1) setTour(2); return true; }
        if (item.id !== active.data.targets[active.index].id) { active.penalty += 2; setWrong(v => v + 1); setRace({ ...active }); setBolt('Not that one. +2 seconds.'); }
        else if (active.index === active.data.targets.length - 1) { raceRef.current = null; void finishRace(active); }
        else { active.index++; setRace({ ...active }); setBolt('Nice find. Next one!'); }
        return false;
      },
    };
  }, [accountId, award, fail, finishRace, panel, move, tour]);

  async function chooseRoom(room: Room) { if (move || raceRef.current) return; await activate(room); setSamples(!!room.sample); setPanel(null); }
  function explore() { setMode('explore'); scene.current?.setMode(false); setPlacing(null); }
  function openPanel(value: Panel) { setContents(null); setScan(null); scene.current?.clearScan(); setPanel(value); }
  function startQuiz(game: 'count' | 'where') {
    const room = current.current;
    if (!room || room.sample || room.public || raceRef.current) return;
    explore(); const questions = quizQuestions(room, game);
    if (!questions.length) { const text = game === 'count' ? 'Add items with quantities to play Count it.' : 'Give items different recorded storage places to play Where is it?'; setResult({ title: 'Get this Space ready', text: `${room.name}: ${text}` }); openPanel('result'); return; }
    setQuiz({ spaceId: room.id, spaceName: room.name, game, questions, index: 0, right: 0, chosen: null, ref: crypto.randomUUID() }); openPanel('quiz');
  }
  async function nextQuestion() {
    if (!quiz || quiz.spaceId !== current.current?.id) return;
    if (quiz.index + 1 < quiz.questions.length) { setQuiz({ ...quiz, index: quiz.index + 1, chosen: null }); return; }
    const submit = async () => { await award('game', quiz.ref, { game: quiz.game, right: quiz.right }); setResult({ title: 'You know your stuff', text: `${quiz.right} of ${quiz.questions.length} right in ${quiz.spaceName}` }); setPanel('result'); };
    try { await submit(); } catch (e) { fail(e); setResult({ title: 'Round complete', text: `${quiz.right} right. XP has not been confirmed yet.`, retry: submit }); setPanel('result'); }
  }
  async function finishTour() { setTour(null); if (accountId) await award('tour', accountId); }
  async function confirmMove() {
    if (!move || !current.current) return;
    const source = current.current, pending = move, body = placementBody(pending.item, pending.destination);
    await writer.current?.flush();
    await request('/world/placements/' + pending.item.id, body, 'PUT');
    setMove(null);
    const undo = async () => {
      await request('/world/placements/' + pending.item.id, { area_id: body.expected_area_id, bin_id: body.expected_bin_id, expected_area_id: body.area_id, expected_bin_id: body.bin_id }, 'PUT');
      setUndoMove(null); setBolt('Storage assignment restored.');
      // Restore only this item's coordinates, preserving later decoration edits.
      const key = 'item:' + pending.item.id;
      const restored = { ...layout.current, places: { ...layout.current.places, [key]: pending.previous.places[key] } };
      writer.current?.queue(restored);
      try { await writer.current?.flush(); await refreshRooms(source.id); }
      catch { setError('The storage assignment was restored. The visual layout could not be saved; reload World to see the latest layout.'); }
    };
    layout.current = pending.layout; writer.current?.queue(pending.layout);
    try { await writer.current?.flush(); await refreshRooms(source.id); setBolt(`${pending.item.name} moved.`); }
    catch { setError('The storage assignment was moved, but the visual layout could not be saved. Use Undo to restore the assignment, or reload World.'); }
    setUndoMove(() => undo);
  }
  function cancelMove() { if (busyRef.current) return; if (move && current.current) { layout.current = move.previous; scene.current?.load({ ...current.current, items: current.current.items.map(item => ({ ...item, photo: privateImageSrc(item.photo, accountId) })) }, move.previous); scene.current?.setMode(mode === 'build'); setMove(null); } }
  const sampleRooms: Room[] = catalog ? catalog.samples.map(s => ({ id: 'sample:' + s.id, name: s.name, sample: s.id, items: [], bins: [], storage_areas: [], can_edit: false, revision: 0, layout: null, item_count: 0, capped: false })) : [];
  const visibleRooms = samples ? sampleRooms : rooms;
  const dailyVisible = daily?.available && daily.scope_id === selected?.id && daily.targets.length === 5 && daily.targets.every(t => t.space_id === selected.id && selected.items.some(i => i.id === t.id));
  const readyQuests = progress?.quests.filter(q => !q.claimed && q.progress >= q.goal).length || 0;
  const currentQuestion = quiz?.questions[quiz.index];

  const spaceButtons = <>{visibleRooms.map(room => <button className="chip-btn" key={room.id} disabled={!!race || !!move || busy} aria-pressed={selected?.id === room.id} onClick={() => void run(() => chooseRoom(room))}>{room.name}</button>)}
        {!publicData && rooms.length > 0 && <button className="chip-btn" disabled={!!race || !!move || busy || !catalog} aria-pressed={samples} onClick={() => void run(async () => { const next = (samples ? rooms : sampleRooms)[0]; if (next) await chooseRoom(next); })}>{samples ? 'My spaces' : 'Sample spaces'}</button>}
      </>;

  const guide = compact && !publicData && !guideHidden && mode === 'explore' && !contentsGroup && !scan && !panel && !race && !move && tour === null && !!selected;
  const buildVisible = mode === 'build' && (!compact || (!contentsGroup && !scan && !panel && !move));
  const side = compact && !panel && !move && (guide || !!contentsGroup || (!!scan && !race) || buildVisible);
  return <div className="fz-world" data-embedded={embedded || undefined} data-layout={compact ? 'compact' : undefined} data-mode={mode} data-side={side || undefined} data-playing={!!race || undefined} ref={root}>
    <div id="stage" data-world-stage aria-label="3D inventory world. Tap an object to scan it. Scroll or pinch to zoom." />
    {(loading || !catalog) && !error && <div className="loading" role="status">Building your world...</div>}
    <div className="ui top" data-world-top>
      <div className="brand"><b>{compact ? 'FIND world' : 'FindEZ World'}</b><span>how FIND sees your stuff</span></div>
      {!embedded && !publicData && <Link className="world-back" href="/worlds/personal" onClick={e => { if (saveState === 'saving' || move) { e.preventDefault(); void run(async () => { await writer.current?.flush(); if (!move) router.push('/worlds/personal'); }); } }}>Back to FindEZ</Link>}
      <nav className="modes" aria-label="World mode"><button aria-pressed={mode === 'explore'} onClick={() => { explore(); close(); if (compact) { setContents(null); setScan(null); scene.current?.focusItems([], null); } }}>Explore</button>
        {!publicData && <button id="m-challenge" disabled={!!race || !!move} onClick={() => { explore(); openPanel('games'); }}>Find it</button>}
        {selected?.can_edit && !selected.sample && <button id="m-build" disabled={!!race || !!move || saveState === 'error'} aria-pressed={mode === 'build'} onClick={() => { close(); if (compact) { setContents(null); setScan(null); } setMode('build'); scene.current?.setMode(true); setBolt(compact ? 'Choose a piece, then tap the floor. Edit & room tools has Turn, Copy and Remove.' : 'Tap a piece, then tap the floor. Drag to move. R turns, D copies, Delete removes decoration.'); }}>Build</button>}
      </nav>
      {compact && <button className="hb world-mobile-menu" onClick={() => openPanel('menu')}>Menu</button>}
      {!publicData && !compact && <div className="hud">
        <button id="bLvl" className="hb" onClick={() => openPanel('level')}>Level {progress?.level || 1}{progress ? ` · ${progress.xp_to_next_level} XP to go${progress.streak ? ` · ${progress.streak} day streak` : ''}` : ''}</button>
        <button id="bQuests" className="hb" onClick={() => openPanel('quests')}>Quests{readyQuests ? ` · ${readyQuests} ready` : ''}</button>
        {selected?.can_edit && <button id="bAdd" className="hb dark" disabled={!!race || !!move || busy} onClick={() => openPanel('add')}>+ Add item</button>}
        <button className="hb" aria-label="Show the tour" onClick={() => { explore(); close(); setTour(0); }}>?</button>
        <button className="hb" disabled={!!race} onClick={() => openPanel('search')}>Find an item</button>
        <span className="world-save" role="status">{saveState === 'saving' ? 'Saving...' : saveState === 'saved' ? 'Saved' : saveState === 'error' ? 'Not saved' : ''}</span>
      </div>}
      {publicData && <Link className="hb" href="/signup">Make your own on FindEZ</Link>}
      {!compact && selected?.sample && <p className="sample-note">{rooms.length ? 'Sample space. Explore for inspiration.' : 'Save your first space to see your own stuff here.'}</p>}
      {!compact && selected?.capped && <p className="sample-note">Showing the first 400 items. Your full inventory is available in FindEZ.</p>}
    </div>
    {error && <div className="world-alert" role="alert"><span>{error}</span><button onClick={() => location.reload()}>Reload World</button><button aria-label="Dismiss error" onClick={() => setError('')}>×</button></div>}
    {guide && selected && <SpaceMission room={selected} storageCount={groups.filter(g => g.key !== 'unplaced').length} busy={busy} hide={() => setGuideHidden(true)} play={() => void run(loadDaily)} browse={() => openPanel('browse')} quests={() => openPanel('quests')} />}
    {contentsGroup && !panel && !move && <StorageBrowser embedded={compact} key={selected!.id + contentsGroup.key} group={contentsGroup} capped={!!selected?.capped} playing={!!race} onPage={showContentsPage} close={() => { setContents(null); scene.current?.focusItems([], null); }} onItem={item => { if (raceRef.current) { callbacks.current?.onTap(item); } else { setContents(null); scene.current?.scan(item.id); } }} />}
    {scan && !panel && !race && <section className="card" aria-label="Item scan" aria-live="polite">
      <button className="x" aria-label="Close scan" onClick={() => { setScan(null); scene.current?.clearScan(); }}>×</button>
      <div className="steps">{['Find', 'Identify', 'Number', 'Detail'].map((step, i) => <span key={step} className={'step' + ((scanFrame?.phase || 0) >= i ? ' on' : '')}>{step}</span>)}</div>
      <h2>{scan.name}</h2><dl className="facts">{scan.quantity != null && <><dt>Quantity</dt><dd className="count">{scan.quantity}</dd></>}{placeLine(scan) && <><dt>Place</dt><dd>{placeLine(scan)}</dd></>}{scan.running_low && <><dt>Status</dt><dd className="short">Running low</dd></>}</dl>
    </section>}
    {scanFrame && scan && !panel && !race && <><div className="tag3d" style={{ left: scanFrame.x, top: scanFrame.y - 16 }}>{scanFrame.phase >= 2 && scan.quantity != null ? `${scan.quantity} · ` : ''}{scan.name}</div>{scanFrame.brackets && <div className="world-scan-box" style={scanFrame.box} />}</>}
    {race && <div className={'target' + (wrong ? ' shake' : '')} key={wrong} aria-label="Current Find it target"><span>{race.index + 1}/5</span><b>{race.data.targets[race.index].name}</b><time>{elapsed.toFixed(1)}s</time><button aria-label="End this round" onClick={() => { raceRef.current = null; setRace(null); }}>×</button>{compact && <small className="world-race-hint" role="status">{wrong && bolt.startsWith('Not that') ? 'Wrong item · +2 seconds' : 'Open Storage and tap the matching item.'}</small>}</div>}
    <div className="ui bottom" data-world-bottom>
      {!compact && mode !== 'build' && <p className="hint">{selected?.sample || publicData ? 'Tap anything to see how FIND sees it.' : 'Open storage to explore its contents. Unplaced items are kept in the tray.'} Scroll or pinch to zoom in.</p>}
      {!compact && groups.length > 0 && <div className="world-storage-rail" aria-label="Storage in this Space"><button className="tb" aria-pressed={!contents && !scan} onClick={() => { setContents(null); setScan(null); scene.current?.focusItems([], null); }}>Room overview</button>{groups.map(group => <button className="tb" key={group.key} disabled={!!move || busy} aria-pressed={contents === group.key} onClick={() => { setScan(null); scene.current?.clearScan(); setContents(group.key); }}><span>{group.name}</span><b>{group.items.length}{selected?.capped ? '+' : ''}</b></button>)}</div>}
      {buildVisible && catalog && <div className="bbar">{compact && <h2 className="world-build-title">Make this Space yours</h2>}<div className="btools world-build-primary">
        <button className="tb" onClick={() => { scene.current?.setPlacing(null); setPlacing(null); }}>Cursor</button><button className="tb" onClick={() => scene.current?.undo()}>Undo</button><button className="tb" onClick={() => scene.current?.redo()}>Redo</button>
        <details className="world-build-more" open={!compact || !!selection || !!placing}><summary>Edit &amp; room tools</summary><div className="btools"><button className="tb" disabled={!selection && !placing} onClick={() => scene.current?.rotate(1)}>Turn</button><button className="tb" disabled={selection?.kind !== 'piece'} onClick={() => scene.current?.duplicate()}>Copy</button><button className="tb" disabled={selection?.kind !== 'piece'} onClick={() => scene.current?.remove()}>Remove</button>
        <button className="tb" onClick={() => openPanel('storage')}>Storage area</button><button className="tb" aria-pressed={styles} onClick={() => setStyles(!styles)}>Room</button><button className="tb" aria-pressed={!muted} onClick={() => { setMuted(!muted); scene.current?.setMuted(!muted); }}>{muted ? 'Sound off' : 'Sound on'}</button><button className="tb" onClick={() => void run(async () => { await writer.current?.flush(); openPanel('share'); })}>Share</button>
      </div></details></div><div className="bctx">
        {selection && <div className="itembar"><b>{selection.name}</b><span className="tiny">{compact ? 'Drag to move. Use Turn, Copy or Remove above.' : `Drag to move · R to turn${selection.kind === 'piece' ? ' · D to copy' : ''}`}</span></div>}
        {placing && <div className="placing">Tap the floor to place {catalog.pieces.find(p => p.id === placing)?.name}.<button className="tb" onClick={() => { scene.current?.setPlacing(null); setPlacing(null); }}>Cancel</button></div>}
        {!styles && <div className="cats">{catalog.categories.map(([id, name]) => <button className="cat" key={id} aria-pressed={category === id} onClick={() => setCategory(id)}>{name}</button>)}</div>}
        <div className="thumbs">{styles ? catalog.themes.map(theme => { const locked = theme.level > (progress?.best_level || 1); return <button className={'thumb' + (locked ? ' locked' : '')} key={theme.id} onClick={() => locked ? setBolt(`Reach level ${theme.level} to unlock ${theme.name}.`) : scene.current?.setFloor(theme.id)}>{theme.image && <img src={theme.image} alt="" />}<span>{theme.name}</span>{locked && <em>Level {theme.level}</em>}</button>; }) : catalog.pieces.filter(p => p.category === category).map(piece => { const level = progress?.rules.locks[piece.id] || 1, locked = level > (progress?.best_level || 1); return <button className={'thumb' + (locked ? ' locked' : '')} key={piece.id} aria-pressed={placing === piece.id} onClick={() => { if (locked) setBolt(`Reach level ${level} to unlock the ${piece.name.toLowerCase()}. Add items and finish quests to get there.`); else { const next = placing === piece.id ? null : piece.id; setPlacing(next); scene.current?.setPlacing(next); } }}>{piece.image && <img src={piece.image} alt="" />}<span>{piece.name}</span>{locked && <em>Level {level}</em>}</button>; })}</div>
      </div></div>}
      {!compact && <div className="spaces" aria-label="Spaces">{spaceButtons}</div>}
      {compact && <nav className="world-mobile-dock" aria-label="World tools">
        <button className="tb world-space-picker" disabled={!!race || !!move || busy} onClick={() => openPanel('spaces')} aria-label={`Spaces: ${selected?.name || 'Choose a Space'}`}>{selected?.name || 'Spaces'} ▾</button>
        <button className="tb" disabled={!groups.length || !!move || busy} onClick={() => openPanel('browse')}>Storage</button>
        <button className="tb" disabled={!!race || !!move} onClick={() => openPanel('search')}>Search</button>
        {selected?.can_edit && <button className="tb" disabled={!!race || !!move || busy} onClick={() => openPanel('add')}>+ Item</button>}
      </nav>}
    </div>
    {bolt && catalog?.bolt && !panel && tour === null && (!compact || (!race && !guide)) && <div className="bolt in" style={{ bottom: mode === 'build' ? 250 : 90 }} aria-live="polite"><img src={catalog.bolt} alt="Bolt" /><div className="say">{bolt}</div></div>}
    {xp && <div className="xpf" key={xp.key} style={{ left: '50%', top: '32%' }}>+{xp.amount} XP</div>}
    {undoMove && <div className="toast">Item moved<button className="tact" disabled={busy} onClick={() => void run(undoMove)}>Undo</button><button className="tact" aria-label="Dismiss" onClick={() => setUndoMove(null)}>×</button></div>}
    {move && <WorldDialog title={`Move ${move.item.name}?`} close={cancelMove}><p>Move to {move.destination?.name || 'no storage area'} in {selected?.name}?</p><div className="row"><button className="btn" disabled={busy} onClick={() => void run(confirmMove)}>Move</button><button className="btn ghost" disabled={busy} onClick={cancelMove}>Cancel</button></div></WorldDialog>}
    {panel && <WorldDialog title={panel === 'menu' ? 'World menu' : panel === 'spaces' ? 'Choose a Space' : panel === 'browse' ? 'Storage in this Space' : panel === 'level' ? `Level ${progress?.level || 1}` : panel === 'levelup' ? `Level ${levelAward?.level}!` : panel === 'quests' ? 'Your quests' : panel === 'add' ? 'Add your stuff' : panel === 'games' ? 'Pick a game' : panel === 'daily' ? 'Find it' : panel === 'quiz' ? quiz?.game === 'count' ? 'Count it' : 'Where is it?' : panel === 'storage' ? 'Add storage area' : panel === 'share' ? 'Share your space' : panel === 'search' ? 'Find an item' : result?.title || 'Round complete'} close={dismiss}>
      {panel === 'menu' && <div className="world-mobile-actions">
        {!embedded && <Link className="btn ghost" href="/worlds/personal" onClick={e => { if (saveState === 'saving' || move) { e.preventDefault(); void run(async () => { await writer.current?.flush(); if (!move) router.push('/worlds/personal'); }); } }}>Back to FindEZ</Link>}
        <button className="btn ghost" disabled={!!race || !!move} onClick={() => { explore(); close(); setGuideHidden(false); }}>Space mission</button>
        <button className="btn ghost" onClick={() => openPanel('level')}>Level {progress?.level || 1} · {progress?.xp || 0} XP</button>
        <button className="btn ghost" onClick={() => openPanel('quests')}>Quests{readyQuests ? ` · ${readyQuests} ready` : ''}</button>
        <button className="btn ghost" disabled={!!race || !!move} onClick={() => openPanel('search')}>Find an item</button>
        {selected?.can_edit && <button className="btn ghost" disabled={!!race || !!move || busy} onClick={() => openPanel('add')}>Add item</button>}
        <button className="btn ghost" onClick={() => { explore(); close(); setTour(0); }}>Help & tour</button>
        <button className="btn ghost" aria-pressed={!muted} onClick={() => { setMuted(!muted); scene.current?.setMuted(!muted); }}>{muted ? 'Sound off' : 'Sound on'}</button>
        {selected?.can_edit && <button className="btn ghost" disabled={!!race || !!move || busy} onClick={() => void run(async () => { await writer.current?.flush(); openPanel('share'); })}>Share Space</button>}
        <p className="muted">{saveState === 'saving' ? 'Saving...' : saveState === 'error' ? 'Layout not saved. Reload World before making more changes.' : saveState === 'saved' ? `Saved · ${selected?.name}` : selected?.name}</p>
      </div>}
      {panel === 'spaces' && <div className="world-mobile-list">{spaceButtons}</div>}
      {panel === 'browse' && <div className="world-mobile-list">
        {selected?.capped && <p>Showing the first 400 records. Your full inventory is available in FindEZ.</p>}
        {groups.map(group => <button className="btn ghost" key={group.key} onClick={() => { close(); setScan(null); setContents(group.key); }}><b>{group.name}</b><span>{group.items.length}{selected?.capped ? '+' : ''} items</span></button>)}
      </div>}
      {panel === 'level' && progress && <><p>{progress.xp} XP this season · {progress.xp_to_next_level ? `${progress.xp_to_next_level} XP to the next level` : 'Top level reached'}</p><p className="muted">{progress.season.name} · Lifetime rank {progress.lifetime_rank} · {progress.lifetime_xp} lifetime XP</p><dl className="facts">{Object.entries(progress.rules.xp).map(([kind, amount]) => <div className="world-fact" key={kind}><dt>{kind === 'spot' ? 'Give a new item a spot' : kind}</dt><dd>+{amount} XP</dd></div>)}</dl><p className="muted">Daily limits apply. Repeat scans and retried actions do not award XP again. Unlocked pieces stay yours across seasons.</p></>}
      {panel === 'levelup' && levelAward && <><p>New things to make your space your own.</p><ul>{levelAward.new_unlocks.pieces.map(id => <li key={id}>{catalog?.pieces.find(p => p.id === id)?.name || id}</li>)}{levelAward.new_unlocks.styles.map(id => <li key={id}>{catalog?.themes.find(t => t.id === id)?.name}</li>)}</ul><button className="btn" onClick={() => { close(); if (selected?.can_edit) { setMode('build'); scene.current?.setMode(true); setStyles(true); } }}>See your new pieces</button></>}
      {panel === 'quests' && <ul className="quests">{progress?.quests.map(q => <li key={q.id}><span>{q.title}<br /><em>{q.progress}/{q.goal} · {q.xp} XP</em></span>{q.claimed ? <em>Collected</em> : <button className="btn sm" disabled={busy || q.progress < q.goal} onClick={() => void run(async () => { await showAward(await request<Award>(`/world/quests/${q.id}/claim`, {})); })}>Collect</button>}</li>)}</ul>}
      {panel === 'add' && selected?.can_edit && accountId && <ItemForm key={selected.id} accountId={accountId} room={selected} onBusy={value => { busyRef.current = value; setBusy(value); }} saved={async (itemId, added) => { await writer.current?.flush(); await refreshRooms(selected.id); close(); if (added) await award('add', itemId).catch(fail); setBolt(added ? 'Your item has a home now.' : 'Added to the quantity of your existing item. Its storage assignment is unchanged.'); scene.current?.pop(itemId); scene.current?.scan(itemId); }} />}
      {panel === 'storage' && selected?.can_edit && accountId && <StorageForm key={selected.id} accountId={accountId} spaceId={selected.id} onBusy={value => { busyRef.current = value; setBusy(value); }} saved={async () => { await writer.current?.flush(); await refreshRooms(selected.id); close(); setBolt('Storage area added. Choose Build to move it into place.'); }} />}
      {panel === 'share' && selected?.can_edit && accountId && <SharePanel key={selected.id} accountId={accountId} spaceId={selected.id} />}
      {panel === 'games' && <><p className="world-game-purpose">Playing in <strong>{selected?.name || 'this Space'}</strong>. Every game uses only this Space’s items and recorded places.</p><div className="games"><button className="game" disabled={busy || !!selected?.sample || !selected} onClick={() => void run(loadDaily)}><b>Find it</b><span>Five things in {selected?.name || 'this Space'}. Tap each one as fast as you can. A wrong tap adds 2 seconds. Under 15 seconds earns three stars.</span></button><button className="game" disabled={busy || !selected || !!selected.sample || !!selected.public} onClick={() => startQuiz('count')}><b>Count it</b><span>How many do you have? Questions from this Space.</span></button><button className="game" disabled={busy || !selected || !!selected.sample || !!selected.public} onClick={() => startQuiz('where')}><b>Where is it?</b><span>Pick the place where each item lives.</span></button></div></>}
      {panel === 'daily' && (daily ? <><p>Five real items in {selected?.name}. Open storage or Unplaced items to find them. Wrong taps add 2 seconds.</p>{compact && <p className="muted">Goal: learn this Space so you can find your things faster later.</p>}{daily.score != null ? <p>Already played today: {daily.score.toFixed(1)} seconds. Come back tomorrow.</p> : !dailyVisible ? <p>Today’s round needs five visible items in this Space. Keep adding your real inventory and check back tomorrow.</p> : <button className="btn" disabled={busy} onClick={() => { const value = { data: daily, index: 0, started: performance.now(), penalty: 0 }; raceRef.current = value; setRace(value); setSamples(false); setContents(null); scene.current?.focusItems([], null); setWrong(0); close(); }}>Let’s find them</button>}<ol className="board">{board.map((s, i) => <li key={i}><span>{s.name}{s.you ? ' (you)' : ''}</span><span>{s.seconds.toFixed(1)}s</span></li>)}</ol></> : <p role="status">Preparing today’s round...</p>)}
      {panel === 'quiz' && quiz && currentQuestion && <><p className="muted">{quiz.spaceName} · {quiz.index + 1}/{quiz.questions.length}</p><h3>{quiz.game === 'count' ? `How many ${currentQuestion.item.name} do you have?` : `Where is ${currentQuestion.item.name}?`}</h3><div className="opts">{currentQuestion.options.map(option => <button className={'opt' + (quiz.chosen !== null ? option === currentQuestion.answer ? ' right' : option === quiz.chosen ? ' wrong' : '' : '')} key={option} disabled={quiz.chosen !== null} onClick={() => { const correct = option === currentQuestion.answer; setQuiz({ ...quiz, chosen: option, right: quiz.right + (correct ? 1 : 0) }); setBolt(correct ? 'You know your stuff.' : 'Not quite. Now you know.'); }}>{option}</button>)}</div>{quiz.chosen !== null && <button className="btn" disabled={busy} onClick={() => void run(nextQuestion)}>{quiz.index + 1 === quiz.questions.length ? 'Finish' : 'Next'}</button>}</>}
      {panel === 'result' && result && <>{result.seconds != null && <p className="stars" aria-label={`${result.seconds < 15 ? 3 : result.seconds < 25 ? 2 : 1} stars`}>{result.seconds < 15 ? '★★★' : result.seconds < 25 ? '★★☆' : '★☆☆'}</p>}<p>{result.text}</p>{compact && !result.retry && result.seconds != null && <button className="btn" onClick={() => startQuiz('where')}>Practice locations</button>}{result.retry ? <button className="btn" disabled={busy} onClick={() => void run(result.retry!)}>Save result</button> : <div className="row"><button className="btn" onClick={() => void navigator.clipboard.writeText(`FindEZ World: ${result.text}${result.seconds != null ? ' in Find it' : ''}\n${location.origin}/world`).then(() => setBolt('Copied your result.')).catch(fail)}>Copy result</button><button className="btn ghost" onClick={() => void run(loadDaily)}>Leaderboard</button></div>}</>}
      {panel === 'search' && <><label className="world-sr" htmlFor="world-search">Item name</label><input id="world-search" type="text" value={query} onChange={e => setQuery(e.target.value)} placeholder="Search your items" /><div className="world-search-results">{rooms.flatMap(room => room.items.filter(item => item.name.toLowerCase().includes(query.toLowerCase())).map(item => ({ room, item }))).slice(0, 60).map(({ room, item }) => <button key={item.id} onClick={() => void run(async () => { await activate(room); close(); scene.current?.scan(item.id); })}>{item.name}<small>{placeLine(item) || room.name}</small></button>)}</div></>}
    </WorldDialog>}
    {tour !== null && <div id="tour" className={tour === 1 ? '' : 'dim'}><div className="tbub world-tour-bubble" role="dialog" aria-label={TOUR[tour][0]}><div className="thead">{catalog?.bolt && <img src={catalog.bolt} alt="Bolt" />}<h3>{TOUR[tour][0]}</h3></div><p>{TOUR[tour][1]}</p><div className="row"><button className="btn ghost" onClick={() => void run(finishTour)}>Skip tour</button><button className="btn" onClick={() => tour === TOUR.length - 1 ? void run(finishTour) : setTour(tour + 1)}>{tour === TOUR.length - 1 ? 'Let’s go' : tour === 1 ? 'Skip this' : 'Next'}</button></div></div></div>}
    {panel === 'levelup' && <div className="confetti" aria-hidden="true">{Array.from({ length: 30 }, (_, i) => <i key={i} style={{ left: `${(i * 37) % 100}%`, background: ['#f2c14e', '#f2a5a0', '#82c957', '#a8d8ef'][i % 4], animationDelay: `${(i % 6) * .08}s`, '--dx': `${(i % 2 ? 1 : -1) * (20 + i * 3)}px` } as CSSProperties} />)}</div>}
  </div>;
}
