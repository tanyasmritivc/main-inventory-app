import { PhotoTags, MemoryGraph, Drawers } from './SceneDetails';
import { useRouter } from 'next/navigation';
import { submitPrompt } from './navigation';

export function StoryA() {
  const router = useRouter();
  return (
<section className="pinS" id="storyA" style={{"height": "560vh"}} aria-label="FindEZ">
  <div className="stage" id="stA">
    <div id="orbit"></div>
    <div id="graph"><MemoryGraph /></div>

    <div className="tx center" id="a0"><h1>Describe your world.</h1><p className="sub" id="a0s">Snap a shelf or type a list to build an inventory.</p></div>
    <div className="tx" id="a1">
      <h2>Take a picture.<br /><span className="o">Review. Save.</span></h2>
      <p className="sub">FindEZ suggests objects, quantities and confidence from your photo. Review the results, choose a Space and save the items you want to remember.</p>
      <div className="counts"><div><b id="cntA">0</b><span>Objects found</span></div><div><b className="o" id="cntB">0</b><span>Needs a look</span></div></div>
    </div>
    <div className="tx light" id="a2">
      <h2>Knowing what it is is useful. Knowing everything around it is memory.</h2>
      <p className="sub">Keep the charger from your bench photo with its saved location, notes and documents. Ask FindEZ about the details you have recorded.</p>
    </div>
    <div className="tx center" id="a3"><h2>Not just “Workshop”. Exactly where.</h2></div>
    <div className="tx" id="a4">
      <h2>Ask about the things you saved.</h2>
      <p className="sub">Ask what you have, how many are left or where you saved them. Follow the answer back to your inventory records.</p>
    </div>

    <div id="m">
      <div className="ly" id="lComp">
    <form className="composer" id="cform" action="/signup" method="get" onSubmit={(event) => submitPrompt(event, router.push)}>
      <label htmlFor="ask" style={{"position": "absolute", "width": "1px", "height": "1px", "overflow": "hidden", "clip": "rect(0 0 0 0)"}}>Describe what to add</label>
      <textarea id="ask" name="prompt" rows={2} onKeyDown={(event) => { if (event.key === "Enter" && !event.shiftKey) { event.preventDefault(); event.currentTarget.form?.requestSubmit(); } }} placeholder="Start an inventory for my garage"></textarea>
      <div className="crow">
        <button className="cb o" type="button" aria-label="Attach" data-go="" onClick={() => router.push('/signup')}><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#111112" strokeWidth="1.8" strokeLinecap="round"><path d="M12 5v14M5 12h14"></path></svg></button>
        <button className="cb cam" type="button" aria-label="Take a photo" data-go="" onClick={() => router.push('/signup')}><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="#111112" strokeWidth="1.8" strokeLinejoin="round"><path d="M4 8.5A1.5 1.5 0 0 1 5.5 7H8l1.5-2h5L16 7h2.5A1.5 1.5 0 0 1 20 8.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5z"></path><circle cx="12" cy="13" r="3.4"></circle></svg></button>
        <div className="sp"></div>
        <button className="cb mic" type="button" aria-label="Speak" data-go="" onClick={() => router.push('/signup')}><svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><rect x="9" y="3" width="6" height="11" rx="3"></rect><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"></path></svg></button>
        <button className="cb send" type="submit" aria-label="Send"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M12 19V5M6 11l6-6 6 6"></path></svg></button>
      </div>
    </form>

      </div>
      <div className="ly" id="lPhoto" role="img" aria-label="Workbench with a battery charger, duct tape, screws and gears"><div id="scanfade"></div><div id="scan"></div><div id="tags"><PhotoTags /></div><div className="pcap"><span>ONE PHOTO</span><span id="pcapR">SCANNING</span></div></div>
      <div className="ly" id="lCard"><span className="th"></span><span><small>FROM YOUR BENCH PHOTO</small><b>Battery charger, 18V</b><em>CONFIDENCE 0.97</em></span></div>
      <div className="ly" id="lCab"><div id="cab"><Drawers /><div id="cabBody"></div><div id="rowBox"><span>ROW 5</span></div><div id="drBox"><span>DRAWER PN-F40</span></div></div></div>
      <div className="ly" id="lChat">
        <div className="chd"><i></i>Ask FindEZ</div>
        <div className="chb">
          <div className="ub"><span id="qt"></span></div>
          <div className="ab fd hid" id="ans">AA batteries in the office desk drawer. The garage pack has 18 left.</div>
          <div className="ic fd hid" id="ic1"><span className="sw" style={{"background": "radial-gradient(circle at 35% 30%,#BFE0F7,#6FA9D6)"}}></span><span><b>AA batteries</b><span>Office › Desk drawer</span></span></div>
          <div className="ic fd hid" id="ic2"><span className="sw" style={{"background": "radial-gradient(circle at 35% 30%,#FFB27E,#E8590C)"}}></span><span><b>Battery pack, 18V</b><span>Garage</span></span><em>18 left</em></div>
        </div>
        <div className="tags fd hid" id="tgs"><span>ITEMS · 2</span><span>SPACES · 2</span><span>QUANTITIES</span></div>
      </div>
    </div>

    <div id="review" aria-hidden="true">
      <div className="rh">Workshop › Workbench <small>TODAY</small></div>
      <div className="rr"><b>Battery charger, 18V</b><i>x1</i><em>0.97</em></div>
      <div className="rr"><b>Duct tape</b><i>x1</i><em>0.93</em></div>
      <div className="rr"><b>Socket head screws</b><i>x40</i><em>0.91</em></div>
      <div className="rr warn"><b>Gearbox housing</b><i>x2</i><em>0.79</em></div>
      <div className="rq"><span>⌕</span><span>Where’s the duct tape</span><span>Workbench › Middle</span></div>
    </div>
    <div id="foundC" aria-hidden="true"><small>FOUND</small><b>M4 set screws</b><span>DRAWER PN-F40 · ROW 5 · PARTS CABINET</span></div>
    <div id="crumbs" aria-hidden="true"><span>Workshop</span><span>›</span><span>Workbench</span><span>›</span><span>Parts cabinet</span><span>›</span><span>Row 5</span><span>›</span><span>Drawer PN-F40</span><span>›</span><span>M4 set screws</span></div>
  </div>
</section>
  );
}
