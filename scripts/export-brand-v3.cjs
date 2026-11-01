// Deterministic raster exports from the supplied SVGs. No AI image generation.
// Run: node scripts/export-brand-v3.cjs [--mobile-root /path/to/mobile]
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('../frontend/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const pub = path.join(root, 'frontend/public');
const svg = name => fs.readFileSync(path.join(pub, 'brand', name));
async function png(source, size, output) {
  fs.mkdirSync(path.dirname(output), { recursive: true });
  await sharp(source).resize(size, size).flatten({ background: '#ffffff' }).removeAlpha().png().toFile(output);
}
async function ico(source, output) {
  const sizes = [16, 32, 48];
  const images = await Promise.all(sizes.map(size => sharp(source).resize(size, size).png().toBuffer()));
  const header = Buffer.alloc(6 + 16 * images.length);
  header.writeUInt16LE(1, 2); header.writeUInt16LE(images.length, 4);
  let offset = header.length;
  images.forEach((bytes, i) => {
    const p = 6 + i * 16; header[p] = sizes[i]; header[p + 1] = sizes[i];
    header.writeUInt16LE(1, p + 4); header.writeUInt16LE(32, p + 6);
    header.writeUInt32LE(bytes.length, p + 8); header.writeUInt32LE(offset, p + 12); offset += bytes.length;
  });
  fs.writeFileSync(output, Buffer.concat([header, ...images]));
}
(async () => {
  const light = svg('findez-app-icon-light.svg');
  const dark = svg('findez-app-icon-dark.svg');
  const favicon = svg('findez-favicon.svg');
  await png(favicon, 96, path.join(pub, 'favicon.png'));
  await ico(favicon, path.join(pub, 'favicon.ico'));
  await png(light, 180, path.join(pub, 'apple-touch-icon.png'));
  await png(light, 512, path.join(pub, 'brand/findez-logo-512.png'));
  await png(light, 1024, path.join(pub, 'brand/findez-app-icon-light.png'));
  await png(dark, 1024, path.join(pub, 'brand/findez-app-icon-dark.png'));
  const index = process.argv.indexOf('--mobile-root');
  if (index < 0) return;
  const mobile = path.resolve(process.argv[index + 1]);
  await png(light, 1024, path.join(mobile, 'assets/brand/findez-app-icon.png'));
  await png(dark, 1024, path.join(mobile, 'assets/brand/findez-app-icon-dark.png'));
  await png(light, 1024, path.join(mobile, 'assets/icon/icon.png'));
  const catalog = path.join(mobile, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
  const contents = JSON.parse(fs.readFileSync(path.join(catalog, 'Contents.json')));
  for (const image of contents.images) {
    if (!image.filename) continue;
    const size = Math.round(parseFloat(image.size) * parseFloat(image.scale || '1'));
    await png(image.appearances ? dark : light, size, path.join(catalog, image.filename));
  }
  if (!contents.images.some(i => i.appearances)) {
    contents.images.push({ idiom: 'universal', platform: 'ios', size: '1024x1024', filename: 'Icon-App-Dark-1024.png', appearances: [{ appearance: 'luminosity', value: 'dark' }] });
  }
  await png(dark, 1024, path.join(catalog, 'Icon-App-Dark-1024.png'));
  fs.writeFileSync(path.join(catalog, 'Contents.json'), JSON.stringify(contents, null, 2) + '\n');
  for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
    await png(light, size, path.join(mobile, `android/app/src/main/res/mipmap-${density}/ic_launcher.png`));
  }
  for (const size of [16, 32, 64, 128, 256, 512, 1024]) {
    await png(light, size, path.join(mobile, `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png`));
  }
  for (const size of [192, 512]) {
    for (const prefix of ['Icon-', 'Icon-maskable-']) await png(light, size, path.join(mobile, `web/icons/${prefix}${size}.png`));
  }
  await png(favicon, 32, path.join(mobile, 'web/favicon.png'));
  await ico(light, path.join(mobile, 'windows/runner/resources/app_icon.ico'));
})().catch(error => { console.error(error); process.exit(1); });
