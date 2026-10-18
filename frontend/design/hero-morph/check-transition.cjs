const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const origin = process.env.FINDEZ_QA_ORIGIN || 'http://127.0.0.1:3214';
assert(['http://127.0.0.1:3214', 'http://127.0.0.1:3215', 'https://findez.ai'].includes(origin));
const phase = origin === 'https://findez.ai' ? 'live' : origin.endsWith('3215') ? 'candidate' : 'local';
const output = path.join(__dirname, 'publish', phase);
const result = { origin, checks: [], errors: [] };
const settle = async page => {
  await page.waitForTimeout(80);
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
};

(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  try {
    const context = await browser.newContext();
    await context.route('**/*', route => {
      const url = route.request().url();
      if (url.startsWith(origin + '/') || url.startsWith('data:')) return route.continue();
      return route.abort();
    });
    const page = await context.newPage();
    page.on('pageerror', error => result.errors.push(error.message));
    for (const [width, height] of [[1440, 900], [1280, 720], [390, 844]]) {
      await page.setViewportSize({ width, height });
      await page.goto(origin + '/', { waitUntil: 'networkidle' });
      await page.evaluate(() => document.fonts.ready);
      if (await page.getByRole('button', { name: 'Got it', exact: true }).count()) await page.getByRole('button', { name: 'Got it', exact: true }).click();
      await page.addStyleTag({ content: 'nextjs-portal{display:none}' });
      await settle(page);
      const geometry = await page.evaluate(() => {
        const hero = document.querySelector('#hero').getBoundingClientRect();
        const see = document.querySelector('#see').getBoundingClientRect();
        return { release: hero.top + scrollY + 1300, end: hero.bottom + scrollY, next: see.top + scrollY };
      });
      assert(Math.abs(geometry.end - geometry.next) < .1, 'No layout gap between sections');
      const samples = [];
      const positions = width >= 980
        ? [-2, -1, 0, 1, 2, 100, 300, 500, 700].map(n => geometry.release + n)
        : [geometry.end - 844, geometry.end - 400, geometry.end, geometry.end + 300];
      for (const y of positions) {
        await page.evaluate(y => window.scrollTo(0, y), y);
        await settle(page);
        const sample = await page.evaluate(() => {
          const rect = el => { const r = el.getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, bottom: r.bottom }; };
          return { y: scrollY, photo: rect(document.querySelector('.fzh-photo')), next: rect(document.querySelector('#see')), found: document.querySelector('.fzh-found').textContent, needs: document.querySelector('.fzh-needs').textContent, overflow: document.documentElement.scrollWidth > innerWidth };
        });
        assert(!sample.overflow);
        assert.equal(sample.found, '6');
        assert.equal(sample.needs, '1');
        samples.push(sample);
      }
      if (width >= 980) {
        const anchor = samples[0].photo.y;
        for (const sample of samples) {
          assert(Math.abs(sample.photo.y + Math.max(0, sample.y - geometry.release) - anchor) < .2, 'Photo releases continuously from sticky position');
          assert(Math.abs(sample.photo.width - samples[0].photo.width) < .1, 'Photo does not resize at handoff');
        }
        for (let i = 0; i < 5; i++) assert(Math.abs(samples[i].photo.y - samples[Math.max(0, i - 1)].photo.y) <= 1.1, 'No jump across the pin boundary');
        await page.evaluate(y => window.scrollTo(0, y), geometry.release - 100);
        await settle(page);
        await page.mouse.move(width / 2, height / 2);
        await page.evaluate(() => {
          window.__heroFrames = [];
          const start = performance.now();
          function record(now) {
            window.__heroFrames.push(scrollY);
            if (now - start < 1400) requestAnimationFrame(record);
          }
          requestAnimationFrame(record);
        });
        await page.mouse.wheel(0, 700);
        await page.waitForTimeout(1500);
        const frames = await page.evaluate(() => window.__heroFrames);
        assert(frames.length > 20);
        assert(frames.at(-1) > geometry.release);
        const deltas = frames.slice(1).map((y, i) => y - frames[i]);
        assert(deltas.every(delta => delta >= -1 && delta < 100), 'Wheel glide has no discontinuity');
        result.checks.push({ name: `${width}x${height} wheel handoff`, frames: frames.length, maxStep: Math.max(...deltas) });
      }
      for (const offset of [0, 300, 650]) {
        const y = width >= 980 ? geometry.release + offset : geometry.end - 400 + offset;
        await page.evaluate(y => window.scrollTo(0, y), y);
        await settle(page);
        await page.screenshot({ path: path.join(output, `handoff-${width}x${height}-${offset}.png`) });
      }
      const graphTop = await page.locator('#graph').evaluate(el => el.getBoundingClientRect().top + scrollY);
      await page.evaluate(y => window.scrollTo(0, y), graphTop);
      await settle(page);
      const letters = await page.locator('#graph [data-lab-style^="memoryLetters."]').evaluateAll(els => els.map(el => Number(el.style.opacity)));
      assert(letters.length > 40 && letters.every(opacity => opacity === 1), 'Existing memory headline reveal is retained');
      await page.evaluate(y => window.scrollTo(0, y), width >= 980 ? geometry.release - 1 : 0);
      await settle(page);
      if (width >= 980) {
        const returned = await page.locator('.fzh-photo').boundingBox();
        assert(Math.abs(returned.y - samples[0].photo.y) < .2, 'Reverse scrolling returns smoothly to the same pinned frame');
      }
      result.checks.push({ name: `${width}x${height} continuous handoff and preserved next screens`, samples });
      console.log('PASS transition ' + width + 'x' + height);
    }
    assert.deepEqual(result.errors, []);
    console.log('PASS no browser errors');
    await context.close();
  } finally {
    fs.writeFileSync(path.join(output, 'transition-results.json'), JSON.stringify(result, null, 2) + '\n');
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
