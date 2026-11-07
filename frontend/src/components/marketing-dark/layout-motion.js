// Read geometry only when a message or draft changes layout, never per frame.
// The browser composites the resulting movement using transforms alone.
export function layoutMotion(life, reduce) {
  const running = new Map();
  life.dispose(() => { running.forEach(animation => animation.cancel()); running.clear(); });
  return (nodes, update, duration) => {
    const elements = [...nodes];
    if (reduce || !elements[0]?.animate) { update(); return; }
    const before = elements.map(element => element.getBoundingClientRect().top);
    elements.forEach(element => { running.get(element)?.cancel(); running.delete(element); });
    update();
    const after = elements.map(element => element.getBoundingClientRect().top);
    elements.forEach((element, index) => {
      const distance = before[index] - after[index];
      if (Math.abs(distance) < .5) return;
      const animation = element.animate([
        { transform: `translateY(${distance}px)` }, { transform: 'translateY(0)' },
      ], { duration, easing: 'cubic-bezier(.32,.72,0,1)' });
      running.set(element, animation);
      animation.onfinish = () => { if (running.get(element) === animation) running.delete(element); };
    });
  };
}
