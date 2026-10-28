import { AUDIENCES } from './sceneData';

export function Who() {
  return (
<section id="who" aria-label="Who uses FindEZ">
  <h2 className="rv">One memory for anyone who owns, shares or manages things.</h2>
  <div className="rows" id="rows">{AUDIENCES.map((list, index) => <div className="mrow" key={index}>{Array.from({length: 4}, (_, copy) => list.map(([text, color]) => <span className={`pill ${color}`} key={`${copy}-${text}`} aria-hidden={copy > 0 ? true : undefined}>{text}</span>))}</div>)}</div>
</section>
  );
}
