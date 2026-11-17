'use client';

import { useState } from 'react';
import styles from './api-docs.module.css';

export const cadSections = [
  ['quickstart', 'Start here', 'workflow choose fusion upload inventory'],
  ['downloads', 'Downloads & versions', 'zip template 0.5.1 0.1.0 candidate'],
  ['install', 'Install the Fusion add-in', 'windows mac folder run toggle open findez'],
  ['update', 'Update an existing installation', 'old preview export only replace restart'],
  ['connect', 'Connect an inventory', 'sign in code pairing permissions disconnect expired'],
  ['first-model', 'Create your first design', 'beginner new blank hybrid plate hole no design experience'],
  ['browse', 'AI search & catalog', 'search location stock reserved checked out available'],
  ['insert', 'Insert a Fusion model', 'step stp f3d placement geometry cancel dimensions'],
  ['bom', 'Compare inside Fusion', 'assembly bom refresh shortages export'],
  ['history', 'Saved BOMs & corrections', 'versions projects history remember match shared review'],
  ['planning', 'Plan several projects', 'shared stock priority allocation multiple projects reservations incoming orders'],
  ['purchasing', 'Quotes, orders & receiving', 'purchase plans supplier prices packs minimum bulk currency approval delivery receipts'],
  ['generate', 'Generate a STEP model', 'rexcad dimensions clarification checksum retry expiry'],
  ['export', 'Export from Fusion', 'json offline export only'],
  ['compare', 'Compare on the web', 'upload inventory results'],
  ['onshape', 'Use an Onshape BOM', 'csv flattened app store direct connection'],
  ['spreadsheet', 'CSV & Excel mapping', 'xlsx columns quantity manufacturer part number barcode units'],
  ['results', 'Statuses & matching', 'covered short missing needs review evidence'],
  ['limits', 'File limits & limitations', 'size rows sheets columns unsupported'],
  ['privacy', 'Privacy & permissions', 'geometry credentials tokens session access read only'],
  ['sample', 'Try a sample design', 'test assembly demo'],
  ['troubleshooting', 'Troubleshooting', 'site reached missing open findez export run failed empty disabled cannot click generation queued permission'],
  ['roadmap', 'Planned capabilities', 'pricing procurement saved corrections vendor models generation'],
  ['support', 'Support', 'help contact email'],
] as const;

const groups = [
  ['Get started', ['quickstart', 'downloads', 'install', 'update', 'connect', 'first-model']],
  ['Work in Fusion', ['browse', 'insert', 'generate', 'bom', 'history']],
  ['Compare a file', ['export', 'compare', 'onshape', 'spreadsheet']],
  ['Plan purchases', ['planning', 'purchasing']],
  ['Reference & help', ['results', 'limits', 'privacy', 'sample', 'troubleshooting', 'roadmap', 'support']],
] as const;

export function CadDocsNavigation() {
  const [query, setQuery] = useState('');
  const needle = query.trim().toLowerCase();
  const matches = cadSections.filter(section => section.join(' ').toLowerCase().includes(needle));
  return <nav className={styles.navigation} aria-label="CAD documentation">
    <label htmlFor="cad-docs-search">Find a CAD topic</label>
    <input id="cad-docs-search" type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Try installation or shortages" />
    {needle && <p role="status">{matches.length} {matches.length === 1 ? 'topic' : 'topics'} found</p>}
    {groups.map(([title, ids]) => {
      const sections = matches.filter(([id]) => (ids as readonly string[]).includes(id));
      return sections.length ? <div key={title} className={styles.navGroup}><span>{title}</span>{sections.map(([id, label]) => <a key={id} href={`#${id}`}>{label}</a>)}</div> : null;
    })}
    {needle && <button type="button" onClick={() => setQuery('')}>Clear search</button>}
  </nav>;
}
