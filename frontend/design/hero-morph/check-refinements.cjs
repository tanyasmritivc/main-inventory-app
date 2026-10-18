const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');

const origin = process.env.FINDEZ_QA_ORIGIN || 'http://127.0.0.1:3214';
assert(['http://127.0.0.1:3214', 'http://127.0.0.1:3215', 'https://findez.ai'].includes(origin));
const phase = origin.startsWith('https') ? 'live' : origin.endsWith('3215') ? 'candidate' : 'local';
const output = path.join(__dirname, 'refinements', phase);
const results = { origin, checks: [], errors: [], sizes: [] };
const settle = async page => {
  await page.waitForTimeout(120);
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
};
const scroll = async (page, y) => { await page.evaluate(y => window.scrollTo(0, y), y); await settle(page); };
const snapshot = page => page.evaluate(() => {
  const rect = el => { const r = el.getBoundingClientRect(); return { x:r.x, y:r.y, width:r.width, height:r.height, right:r.right, bottom:r.bottom }; };
  const hero = document.querySelector('#hero');
  return {
    width:innerWidth, height:innerHeight,
    static:getComputedStyle(document.querySelector('.fzh-stage')).position !== 'sticky',
    text:rect(document.querySelector('.fzh-text')), photo:rect(document.querySelector('.fzh-photo')),
    card:rect(document.querySelector('.fzh-card')), chip:rect(document.querySelector('.fzh-chip')),
    hero:rect(hero), graph:rect(document.querySelector('#graph')),
    found:document.querySelector('.fzh-found').textContent,
    overflow:document.documentElement.scrollWidth > innerWidth,
  };
});

(async () => {
  fs.mkdirSync(output, { recursive:true });
  const browser = await chromium.launch({ executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless:true });
  try {
    const context = await browser.newContext();
    await context.route('**/*', route => {
      const url = route.request().url();
      return url.startsWith(origin + '/') || url.startsWith('data:') ? route.continue() : route.abort();
    });
    const page = await context.newPage();
    page.on('pageerror', error => results.errors.push(error.message));
    await page.goto(origin, { waitUntil:'networkidle' });
    if (await page.getByRole('button', { name:'Got it', exact:true }).count()) await page.getByRole('button', { name:'Got it', exact:true }).click();
    await page.addStyleTag({ content:'nextjs-portal{display:none}' });
    await page.evaluate(() => document.fonts.ready);
    await settle(page);
    assert.equal(await page.locator('.fzh-text .fzh-eyebrow').count(), 0);
    assert.equal(await page.locator('#see').count(), 0);
    assert.equal(await page.getByRole('heading', { name:'Not one giant model. A pipeline.' }).count(), 0);
    const inquiry = page.getByRole('link', { name:'Business inquiries' });
    assert.equal(await inquiry.getAttribute('href'), 'mailto:info@findez.ai?subject=FindEZ%20business%20inquiry');
    results.checks.push('Requested removals, replacement copy and business email destination');

    const sizes = [[2560,1440],[2048,1152],[1920,1080],[1440,900],[1280,720],[1280,600],[1024,768],[980,600],[768,1024],[390,844],[375,667],[1440,540]];
    for (const [width, height] of sizes) {
      await page.setViewportSize({ width,height });
      await scroll(page, 0);
      await page.waitForTimeout(200);
      const value = await snapshot(page);
      assert(!value.overflow, `Horizontal overflow at ${width}x${height}`);
      assert(value.photo.x >= 0 && value.photo.right <= width + .1, `Photo width at ${width}x${height}`);
      assert(value.card.x >= 0 && value.card.right <= width + .1, `Card width at ${width}x${height}`);
      const tagsFit = await page.locator('.fzh-det > span').evaluateAll(els => {
        const photo = document.querySelector('.fzh-photo').getBoundingClientRect();
        return els.every(el => { const tag = el.getBoundingClientRect(); return tag.left >= photo.left && tag.right <= photo.right + 1; });
      });
      assert(tagsFit, `Detection tags clipped at ${width}x${height}`);
      if (!value.static) {
        assert(value.text.right + 4 <= value.card.x, `Copy/card collision at ${width}x${height}`);
        assert(value.text.bottom <= height + .1, `Copy clipped vertically at ${width}x${height}: ${value.text.bottom}`);
        assert(value.card.bottom <= height + .1, `Card clipped vertically at ${width}x${height}: ${value.card.bottom}`);
        assert(value.photo.bottom <= height + .1, `Photo clipped vertically at ${width}x${height}`);
        assert(value.chip.right <= width + .1, `Chip clipped at ${width}x${height}`);
      } else {
        assert(value.text.bottom <= value.photo.y + .1);
        assert(value.photo.bottom <= value.card.y + .1);
      }
      await page.screenshot({ path:path.join(output, `hero-${width}x${height}.png`) });
      results.sizes.push(value);
      console.log('PASS responsive hero ' + width + 'x' + height);
    }
    assert(results.sizes[2].hero.width === 1920);
    assert(results.sizes[2].photo.width > 800, 'Hero uses the wider screen');
    results.checks.push('Hero fits 12 large, standard, narrow and short viewports');

    await page.setViewportSize({ width:1440,height:900 });
    await scroll(page, 0);
    const heroTop = await page.locator('#hero').evaluate(el => el.getBoundingClientRect().top + scrollY);
    const release = heroTop + 1300;
    const boundary = [];
    for (const y of [release - 1, release, release + 1, release + 300]) {
      await scroll(page,y);
      const value = await snapshot(page);
      assert(Math.abs(value.hero.bottom - value.graph.y) < .1);
      assert.equal(value.found,'6');
      boundary.push(value.photo.y + Math.max(0,y - release));
    }
    assert(boundary.every(y => Math.abs(y - boundary[0]) < .2));
    await page.screenshot({ path:path.join(output,'hero-to-memory.png') });
    results.checks.push('Hero releases continuously directly into memory, without the deleted phone scene');

    const zoomTop = await page.locator('#zoom').evaluate(el => el.getBoundingClientRect().top + scrollY);
    const lettersAt = async ratio => {
      await scroll(page,zoomTop - 900 * (1 - ratio));
      return page.locator('#zoom [data-lab-style^="locationLetters."]').evaluateAll(els => els.map(el => Number(el.style.opacity)));
    };
    const early = await lettersAt(0);
    const middle = await lettersAt(.55);
    const complete = await lettersAt(1);
    const reversed = await lettersAt(0);
    assert(early.length > 20 && early.every(n => n === 0));
    assert(middle[0] === 1 && middle.at(-1) === 0);
    assert(complete.every(n => n === 1));
    assert.deepEqual(reversed,early);
    await lettersAt(.55);
    await page.screenshot({ path:path.join(output,'location-letters-midway.png') });
    await lettersAt(1);
    await page.screenshot({ path:path.join(output,'location-letters-complete.png') });
    results.checks.push('Location headline fades letter by letter and reverses with scroll');

    const findTop = await page.locator('#find').evaluate(el => el.getBoundingClientRect().top + scrollY);
    const sceneValues = [];
    for (const y of [findTop - 900,findTop - 450,findTop,findTop - 450]) {
      await scroll(page,y);
      sceneValues.push(await page.locator('#find').evaluate(el => ({ enter:Number(el.style.getPropertyValue('--scene-in')), shape:Number(el.style.getPropertyValue('--scene-shape')), height:el.offsetHeight, orbit:el.querySelector('[data-learning-orbit]').getAttribute('transform') })));
    }
    assert(sceneValues[0].enter < sceneValues[1].enter && sceneValues[1].enter < sceneValues[2].enter);
    assert.equal(sceneValues[1].enter,sceneValues[3].enter);
    assert.notEqual(sceneValues[0].orbit,sceneValues[2].orbit);
    assert(sceneValues.every(v => v.height === sceneValues[0].height), 'Model transition keeps its layout height stable');
    await scroll(page,findTop - 80);
    await page.screenshot({ path:path.join(output,'model-improvement.png') });
    assert(await inquiry.isVisible());
    results.checks.push('Model improvement surface and orbit morph with scroll, reverse cleanly, and keep stable layout');

    for (const id of ['graph','zoom','ask','who','find','app','waitlist','end']) {
      const top = await page.locator('#'+id).evaluate(el => el.getBoundingClientRect().top + scrollY);
      await scroll(page,top);
      assert(!(await snapshot(page)).overflow, 'Overflow at ' + id);
    }
    results.checks.push('Complete landing flow retains all remaining sections with scroll-driven motion');
    await page.emulateMedia({ reducedMotion:'reduce' });
    await scroll(page,0);
    assert((await snapshot(page)).static);
    await scroll(page,await page.locator('#zoom').evaluate(el => el.getBoundingClientRect().top + scrollY));
    const reducedLetters = await page.locator('#zoom [data-lab-style^="locationLetters."]').evaluateAll(els => els.map(el => Number(el.style.opacity)));
    assert(reducedLetters.every(n => n === 1));
    results.checks.push('Reduced motion keeps the full content visible without pinning or letter fades');
    assert.deepEqual(results.errors,[]);
    console.log('PASS all scene, copy, link, motion and browser-error checks');
    await context.close();
  } finally {
    fs.writeFileSync(path.join(output,'results.json'),JSON.stringify(results,null,2)+'\n');
    await browser.close();
  }
})().catch(error => { console.error(error);process.exitCode=1; });
