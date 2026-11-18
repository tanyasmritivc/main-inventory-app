'use client';

import { useState } from 'react';
import styles from './api-docs.module.css';

export const connectionsSections = [
  ['quickstart', 'Start here', 'workflow import purchases'],
  ['ownership', 'Personal & organization records', 'owner permissions admin privacy sharing'],
  ['amazon', 'Import Amazon order history', 'download request csv zip safari folder'],
  ['review', 'Preview & save', 'destination quantity dates duplicates update'],
  ['library', 'Browse your purchase library', 'search filter cancelled returned delivered records'],
  ['before-buying', 'Check before buying', 'asin product link already have'],
  ['inventory', 'Purchases & physical inventory', 'stock quantity ownership manual space'],
  ['manage', 'Update & remove records', 'refresh delete import'],
  ['limits', 'Supported connections & limits', 'shopify seller gmail files size rows'],
  ['privacy', 'Data & privacy', 'addresses payment uploaded file credentials'],
  ['troubleshooting', 'Troubleshooting', 'error failed missing organization empty unsupported'],
  ['support', 'Related guides & support', 'api cad help contact'],
] as const;

export function ConnectionsDocsNavigation() {
  const [query, setQuery] = useState('');
  const needle = query.trim().toLowerCase();
  const matches = connectionsSections.filter(section => section.join(' ').toLowerCase().includes(needle));
  return <nav className={styles.navigation} aria-label="Connections documentation">
    <label htmlFor="connections-docs-search">Find a Connections topic</label>
    <input id="connections-docs-search" type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Try imports or permissions" />
    {needle && <p role="status">{matches.length} {matches.length === 1 ? 'topic' : 'topics'} found</p>}
    <div className={styles.navGroup}><span>Guide & reference</span>{matches.map(([id, title]) => <a key={id} href={`#${id}`}>{title}</a>)}</div>
    {needle && <button type="button" onClick={() => setQuery('')}>Clear search</button>}
  </nav>;
}
