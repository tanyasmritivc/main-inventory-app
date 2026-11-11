import {requestHomeFrame, cancelHomeFrame} from './home-frame';
export function homeLife() {
  const cleanup=[], timers=new Set(), frames=new Map();
  let alive=true;
  return {
    on(target,event,handler,options){target.addEventListener(event,handler,options);cleanup.push(()=>target.removeEventListener(event,handler,options));},
    observer(callback,options){const io=new IntersectionObserver(callback,options);cleanup.push(()=>io.disconnect());return io;},
    timeout(callback,ms){const id=window.setTimeout(()=>{timers.delete(id);if(alive)callback()},ms);timers.add(id);return id;},
    clear(id){window.clearTimeout(id);timers.delete(id);},
    raf(callback){if(frames.has(callback))return frames.get(callback);const id=requestHomeFrame(time=>{frames.delete(callback);if(alive)callback(time)});frames.set(callback,id);return id;},
    dispose(callback){cleanup.push(callback)},
    close(){alive=false;timers.forEach(window.clearTimeout);frames.forEach(cancelHomeFrame);cleanup.reverse().forEach(fn=>fn());timers.clear();frames.clear();}
  };
}
