export function LandingLearning() {
  return <section id="find" className="fzl-learning" data-landing-scene="learning" aria-labelledby="learning-title">
    <div className="fzl-learning-inner">
      <div className="fzl-learning-copy">
        <h2 id="learning-title">Bring your team’s<br /><span>inventory together.</span></h2>
        <p>Give your team one place to capture items, record where they belong and check what’s available.</p>
        <p className="fzl-learning-inquiry">Planning to use FindEZ at work? Talk to us about your team and setup.</p>
        <a className="fzl-learning-cta" href="mailto:info@findez.ai?subject=FindEZ%20business%20inquiry">
          Business inquiries<span aria-hidden="true">&#8599;</span>
        </a>
      </div>
      <div className="fzl-learning-art" aria-hidden="true">
        <svg viewBox="0 0 480 480" fill="none">
          <circle cx="240" cy="240" r="208" stroke="#E3E3E1" />
          <circle cx="240" cy="240" r="168" stroke="#D5D3CD" strokeDasharray="2 10" />
          <circle cx="240" cy="240" r="126" stroke="#E8590C" strokeOpacity=".18" />
          <g data-learning-orbit="">
            <path d="M240 32a208 208 0 0 1 208 208" stroke="#E8590C" strokeWidth="2" />
            <circle cx="240" cy="32" r="7" fill="#E8590C" />
            <circle cx="448" cy="240" r="5" fill="#111112" />
            <circle cx="240" cy="408" r="5" fill="#E8590C" />
            <circle cx="72" cy="240" r="4" fill="#C9C6C0" />
          </g>
          <rect x="164" y="164" width="152" height="152" rx="32" fill="white" />
          <path d="M184 208v-12a12 12 0 0 1 12-12h12m64 0h12a12 12 0 0 1 12 12v12m0 64v12a12 12 0 0 1-12 12h-12m-64 0h-12a12 12 0 0 1-12-12v-12" stroke="#E8590C" strokeWidth="2" />
          <text x="240" y="249" textAnchor="middle" className="fzl-learning-word">FIND</text>
        </svg>
        <span className="fzl-learning-note">Capture. Review. Find.</span>
      </div>
    </div>
  </section>;
}
