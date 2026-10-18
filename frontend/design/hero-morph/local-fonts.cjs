// Local QA only. Uses existing bundled Geist files without a font-server request.
module.exports = new Proxy({}, { get(_target, url) {
  if (typeof url !== 'string') return undefined;
  const family = new URL(url).searchParams.get('family').split(':')[0];
  const directory = process.cwd() + '/../mobile/assets/fonts/';
  return [400, 500].map(weight => {
    const file = family.includes('Mono') ? 'GeistMono-Medium.ttf' : weight === 400 ? 'Geist-Regular.ttf' : 'Geist-Medium.ttf';
    return `/* latin */\n@font-face {font-family:'${family}';font-style:normal;font-weight:${weight};font-display:swap;src: url(${directory + file}) format('truetype');}`;
  }).join('\n');
} });
