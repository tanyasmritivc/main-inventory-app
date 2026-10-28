
export function Business() {
  return (
<section className="pinS" id="biz" style={{"height": "170vh"}}>
  <div className="stage" id="stB">
    <div className="tx" id="b1">
      <h2>Bring your team’s<br />inventory together.</h2>
      <p className="sub">Give your team one place to capture items, record where they belong and check what’s available.</p>
      <p className="sub" style={{"marginTop": "10px"}}>Planning to use FindEZ at work? Talk to us about your team and setup.</p>
      <a className="btn dk" href="mailto:info@findez.ai?subject=FindEZ%20business%20inquiry">Business inquiries ↗</a>
    </div>
    <div className="spc" id="sp1"><div className="sh"><i style={{"background": "var(--or-tint)"}}>⚙</i>Pit cart</div><div className="li"><div>REV HD motors <em className="ok">2 in</em></div><div>Battery packs <em className="no">1 out</em></div><div>Hex keys <em className="ok">set</em></div></div><div className="avs"><b style={{"background": "#FFD7BF"}}>MK</b><b style={{"background": "#BFE0F7"}}>JS</b></div></div>
    <div className="spc" id="sp2"><div className="sh"><i style={{"background": "var(--bl-tint)"}}>▦</i>Lab storeroom</div><div className="li"><div>Multimeters <em className="ok">4 in</em></div><div>Soldering irons <em className="no">2 out</em></div><div>Calipers <em className="ok">3 in</em></div></div><div className="avs"><b style={{"background": "#E7E7EA"}}>AL</b><b style={{"background": "#FFD7BF"}}>RP</b><b style={{"background": "#BFE0F7"}}>DN</b></div></div>
    <div className="spc" id="sp3"><div className="sh"><i style={{"background": "#F2F2F4"}}>▤</i>Shop shelves</div><div className="li"><div>M4 set screws <em className="ok">Drawer PN-F40</em></div><div>Duct tape <em className="ok">3 in</em></div><div>Drill <em className="no">1 out</em></div></div><div className="avs"><b style={{"background": "#BFE0F7"}}>TS</b></div></div>
    <div id="team"><small>ONE PLACE FOR THE TEAM</small><b>Team inventory</b><div className="ts"><span>Pit cart</span><span>Lab storeroom</span><span>Shop shelves</span><span>6 members</span></div></div>
  </div>
</section>
  );
}
