// Every browser resource belongs to one mounted marketing island.
export function lifecycle() {
  const timeouts=new Set(), intervals=new Set(), frames=new Set(), disposers=[];
  let alive=true;
  const timeout=(fn,delay=0)=>{const id=window.setTimeout(()=>{timeouts.delete(id);if(alive)fn()},delay);timeouts.add(id);return id};
  const interval=(fn,delay)=>{const id=window.setInterval(()=>{if(alive)fn()},delay);intervals.add(id);return id};
  const raf=fn=>{const id=window.requestAnimationFrame(t=>{frames.delete(id);if(alive)fn(t)});frames.add(id);return id};
  const listen=(target,event,fn,options)=>{target.addEventListener(event,fn,options);disposers.push(()=>target.removeEventListener(event,fn,options));};
  return {timeout,interval,raf,listen,dispose(fn){disposers.push(fn)},destroy(){alive=false;timeouts.forEach(window.clearTimeout);intervals.forEach(window.clearInterval);frames.forEach(window.cancelAnimationFrame);disposers.forEach(fn=>fn());}};
}
