const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const sharp = require('sharp');

const origin = 'http://127.0.0.1:3214';
const output = path.join(__dirname, 'compare');
const frontend = path.resolve(__dirname, '../..');
const results = { checks: [], errors: [], comparisons: [] };
const check = (name, details) => { results.checks.push({ name, details }); console.log('PASS ' + name); };

async function settle(page, ms = 260) {
  await page.waitForTimeout(ms);
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}
async function scroll(page, y) {
  await page.evaluate(y => window.scrollTo(0, y), y);
  await settle(page);
}
async function state(page) {
  return page.evaluate(() => {
    const $ = name => document.querySelector('.fzh-' + name);
    const rect = el => { const r = el.getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: r.height, bottom: r.bottom, right: r.right }; };
    return {
      found: Number($('found').textContent), needs: Number($('needs').textContent),
      question: $('q').textContent, answer: $('a').textContent,
      lens: $('lens').getAttribute('style'), clip: $('lit').style.clipPath,
      boxes: [...document.querySelectorAll('.fzh-det')].map(el => Number(el.style.opacity)),
      photo: rect($('photo')), text: rect($('text')), card: rect($('card')), s2: rect($('s2')),
      stagePosition: getComputedStyle($('stage')).position,
      overflow: document.documentElement.scrollWidth > innerWidth,
      header: document.querySelector('.fzl-scroll-header').offsetHeight,
      track: document.querySelector('#hero').offsetHeight,
      rootClass: document.querySelector('#hero').className,
      reduced: matchMedia('(prefers-reduced-motion: reduce)').matches,
      viewport: [innerWidth, innerHeight],
    };
  });
}
async function fontsCSS() {
  return ['Geist', 'Geist Mono'].map(family => {
    return [400, 500, 600].map(weight => {
      const name = family.includes('Mono') ? 'GeistMono-Medium.ttf' : weight === 400 ? 'Geist-Regular.ttf' : 'Geist-Medium.ttf';
      const data = fs.readFileSync(path.resolve(frontend, '../mobile/assets/fonts', name)).toString('base64');
      return `@font-face{font-family:'${family}';font-style:normal;font-weight:${weight};src:url('data:font/ttf;base64,${data}') format('truetype');}`;
    }).join('\n');
  }).join('\n');
}

(async () => {
  fs.mkdirSync(output, { recursive: true });
  const browser = await chromium.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true });
  try {
    const context = await browser.newContext();
    await context.route('**/*', async route => {
      const url = route.request().url();
      if (url.startsWith('file:') || url.startsWith(origin) || url.startsWith('data:')) return route.continue();
      if (url.startsWith('https://fonts.googleapis.com/css2')) return route.fulfill({ contentType: 'text/css', body: await fontsCSS() });
      return route.abort();
    });
    const page = await context.newPage();
    page.on('pageerror', error => results.errors.push(error.message));
    await page.goto(origin, { waitUntil: 'networkidle' });
    await page.evaluate(() => document.fonts.ready);
    if (await page.getByRole('button', { name: 'Got it', exact: true }).count()) await page.getByRole('button', { name: 'Got it', exact: true }).click();
    await page.addStyleTag({ content: 'nextjs-portal{display:none}' });
    await settle(page, 1800);
    console.log('Fonts:', await page.evaluate(() => ({ body: getComputedStyle(document.querySelector('.fzh-h1')).fontFamily, mono: getComputedStyle(document.querySelector('.fzh-eyebrow')).fontFamily, faces: [...document.fonts].map(font => ({ family: font.family, status: font.status })) })));

    for (const [width, height] of [[1440, 900], [1280, 720], [390, 844]]) {
      await page.setViewportSize({ width, height });
      await scroll(page, 0);
      await page.mouse.move(1, 1);
      const reference = await context.newPage();
      await reference.setViewportSize({ width, height });
      await reference.goto('file://' + path.join(__dirname, 'reference/index.html'), { waitUntil: 'networkidle' });
      await reference.evaluate(() => document.fonts.ready);
      await settle(reference, 1800);
      for (const y of [0, 500, 900, 1400]) {
        await scroll(page, y);
        await scroll(reference, y);
        const stem = `${width}x${height}-scroll-${y}`;
        const a = path.join(output, `site-${stem}.png`);
        const b = path.join(output, `reference-${stem}.png`);
        await page.screenshot({ path: a });
        await reference.screenshot({ path: b });
        await sharp({ create: { width: width * 2, height, channels: 3, background: '#fff' } })
          .composite([{ input: b, left: 0, top: 0 }, { input: a, left: width, top: 0 }])
          .png().toFile(path.join(output, `pair-${stem}.png`));
        const snapshot = await state(page);
        assert(!snapshot.overflow, `Horizontal overflow at ${stem}`);
        results.comparisons.push({ viewport: [width, height], scroll: y, ...snapshot });
      }
      await reference.close();
      check(`screenshots ${width}x${height}`, 'Reference left, site right; scroll 0, 500, 900, 1400');
    }

    await page.setViewportSize({ width: 1280, height: 720 });
    await scroll(page, 0);
    let snapshot = await state(page);
    assert.equal(snapshot.track - 720, 1300);
    assert.equal(snapshot.stagePosition, 'sticky');
    assert(snapshot.text.right < snapshot.photo.x);
    assert(snapshot.text.bottom <= 720);
    assert(snapshot.card.bottom <= 720);
    check('1280x720 fit', snapshot);
    const heroTop = await page.locator('#hero').evaluate(el => el.getBoundingClientRect().top + scrollY);
    const counts = [];
    for (const [index, progress] of [0, .52, .565, .61, .655, .70, .745, 1].entries()) {
      await scroll(page, heroTop + progress * 1300);
      snapshot = await state(page);
      const expected = Math.min(index, 6);
      assert.equal(snapshot.found, expected);
      assert.equal(snapshot.needs, expected === 6 ? 1 : 0);
      counts.push([progress, snapshot.found, snapshot.needs]);
    }
    check('six staggered boxes and exact counter thresholds', counts);
    const reverse = [];
    for (const progress of [.745, .70, .655, .61, .565, .52, 0]) {
      await scroll(page, heroTop + progress * 1300);
      snapshot = await state(page);
      reverse.push(snapshot.found);
    }
    assert.deepEqual(reverse, [6, 5, 4, 3, 2, 1, 0]);
    check('scrolling back counts down', reverse);

    await scroll(page, 0);
    const photo = await page.locator('.fzh-photo').boundingBox();
    await page.mouse.move(photo.x + photo.width * .2, photo.y + photo.height * .25);
    await settle(page);
    snapshot = await state(page);
    const pointer = snapshot.clip.match(/at ([\d.]+)% ([\d.]+)%/);
    assert(pointer && Math.abs(Number(pointer[1]) - 20) < .5 && Math.abs(Number(pointer[2]) - 25) < .5, snapshot.clip);
    await page.mouse.move(photo.x + photo.width * .8, photo.y + photo.height * .4);
    await settle(page);
    const moved = await state(page);
    assert.notEqual(moved.clip, snapshot.clip);
    await page.mouse.move(1, 1);
    await settle(page, 100);
    const driftA = await state(page);
    await settle(page, 300);
    const driftB = await state(page);
    assert.notEqual(driftA.clip, driftB.clip);
    check('lens pointer tracking and idle drift');

    await page.reload({ waitUntil: 'networkidle' });
    await page.addStyleTag({ content: 'nextjs-portal{display:none}' });
    await scroll(page, 0);
    const questions = [];
    for (let i = 0; i < 4; i++) {
      if (i) await page.waitForFunction(previous => document.querySelector('.fzh-q').textContent !== previous, questions[i - 1].question, { timeout: 4500 });
      snapshot = await state(page);
      const asked = [2, 4, 1, 5][i];
      assert.equal(snapshot.boxes[asked], 1);
      questions.push({ question: snapshot.question, answer: snapshot.answer, elapsed: await page.evaluate(() => performance.now()) });
    }
    for (let i = 2; i < questions.length; i++) {
      const delta = questions[i].elapsed - questions[i - 1].elapsed;
      assert(delta > 3850 && delta < 4450, `Question interval ${delta}`);
    }
    check('four Ask questions cycle every 4.2s and light up the corresponding box', questions);

    await page.setViewportSize({ width: 390, height: 844 });
    await scroll(page, 0);
    snapshot = await state(page);
    assert.equal(snapshot.stagePosition, 'relative');
    assert.equal(snapshot.found, 6);
    assert.equal(snapshot.needs, 1);
    assert(snapshot.text.bottom <= snapshot.photo.y);
    assert(snapshot.photo.bottom <= snapshot.card.y);
    assert(snapshot.card.bottom <= snapshot.s2.y);
    await page.locator('.fzh-photo').scrollIntoViewIfNeeded();
    const mobilePhoto = await page.locator('.fzh-photo').boundingBox();
    await page.mouse.move(mobilePhoto.x + mobilePhoto.width * .3, mobilePhoto.y + mobilePhoto.height * .3);
    await settle(page);
    const mobilePointer = (await state(page)).clip.match(/at ([\d.]+)% ([\d.]+)%/);
    assert(mobilePointer && Math.abs(Number(mobilePointer[1]) - 30) < .5 && Math.abs(Number(mobilePointer[2]) - 30) < .5);
    check('narrow static stack, final counters and pointer tracking', snapshot);

    await page.setViewportSize({ width: 1280, height: 720 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await scroll(page, 0);
    snapshot = await state(page);
    assert.equal(snapshot.stagePosition, 'relative');
    assert.equal(snapshot.found, 6);
    assert.equal(snapshot.needs, 1);
    const reducedClip = snapshot.clip;
    await settle(page, 500);
    assert.equal((await state(page)).clip, reducedClip);
    const animations = await page.locator('.fzh-card li, .fzh-ask .caret').evaluateAll(els => els.map(el => getComputedStyle(el).animationName));
    assert(animations.every(value => value === 'none'));
    check('live reduced-motion switch removes pin, drift, caret and row animation', snapshot);
    await page.screenshot({ path: path.join(output, 'site-reduced-motion-1280x720.png') });
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await scroll(page, 0);
    await page.waitForFunction(() => getComputedStyle(document.querySelector('.fzh-stage')).position === 'sticky', null, { timeout: 3000 }).catch(async error => { console.log('Motion restore state:', await state(page)); throw error; });
    assert.equal((await state(page)).stagePosition, 'sticky');
    check('live motion preference restore');
    assert.equal(await page.locator('#stmt').count(), 0);
    assert.equal(await page.locator('h1').count(), 1);
    assert.equal(await page.locator('#see h2').count(), 0);
    assert.equal(await page.locator('#see img[src$="app-capture.jpg"]').count(), 1);
    await page.goto(origin + '/lab', { waitUntil: 'networkidle' });
    assert.equal(await page.locator('#stmt').count(), 1);
    assert.equal(await page.locator('#fzField').count(), 1);
    check('legacy /lab route preserved');
    assert.deepEqual(results.errors, []);
    check('no browser runtime errors or horizontal overflow');
    await context.close();
  } finally {
    fs.writeFileSync(path.join(output, 'browser-results.json'), JSON.stringify(results, null, 2) + '\n');
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
