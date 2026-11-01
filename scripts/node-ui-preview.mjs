// Offline comparison evidence for the native node screens (not platform acceptance).
// 1. scripts/node-ui-preview.lua drives abyss_node_ui over real Run/Map/Nodes states.
// 2. Each resolved control tree is drawn at 1280x720 (library pictures become labelled
//    stand-in glyphs), then shown beside the matching approved PR19 prototype state.
// Usage: npm run build:data && npm run build:ui && node scripts/node-ui-preview.mjs [outDir]
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { runLua } from './test-lua.mjs';
import { nativeTheme } from './native-ui-theme.mjs';

const prototype = resolve('docs/design/prototype/index.html');
const symbols = readFileSync(prototype, 'utf8').match(/<symbol[\s\S]*?<\/symbol>/g).join('');
const { icon, image } = nativeTheme;
const id = entry => (typeof entry === 'object' ? entry.id : entry);
// Stand-in glyphs from the approved prototype for the picture-library ids used by node screens.
// Relics first so card-art and medallion ids sharing a picture keep their own glyph.
const glyphs = new Map([
  ...Object.entries(icon.relic).filter(([key]) => key !== 'verify').map(([, value]) => [value, 'geo']),
  [icon.hp, 'heart'], [id(icon.gold), 'coin'], [id(icon.deck), 'deck'], [icon.upgrade, 'up'], [icon.remove, 'deck'],
  [icon.cardArt.attack, 'sword'], [icon.cardArt.skill, 'shield'], [icon.cardArt.power, 'geo'], [icon.cardArt.status, 'crack'],
  [icon.node.treasure, 'chest'], [icon.medallion.treasure, 'chest'], [icon.medallion.chestOpen, 'chest'],
  [icon.medallion.camp, 'flame'], [icon.geo, 'geo'], [icon.back, 'up'], [icon.next, 'up'],
  ...Object.entries({ combat: 'sword', elite: 'skull', camp: 'flame', shop: 'stall', event: 'q', treasure: 'chest', boss: 'demon' })
    .map(([kind, glyph]) => [icon.node[kind], glyph]),
  ...Object.entries(icon.potion).filter(([key]) => key !== 'verify').map(([, value]) => [value, 'potion']),
  [icon.map, 'map'],
]);
const rotation = new Map([[icon.back, -90], [icon.next, 90]]);
// The open chest medallion is a distinct library picture; keep the stand-in visibly brighter.
const brighten = new Set([icon.medallion.chestOpen]);

function draw(control, parentSize) {
  if (control.visible === false) return '';
  const [w, h] = control.size ?? parentSize, [x, y] = control.position ?? [0, 0];
  const box = `left:${parentSize[0] / 2 + x - w / 2}px;top:${parentSize[1] / 2 - y - h / 2}px;width:${w}px;height:${h}px;opacity:${control.opacity ?? 1}` +
    (control.rotation ? `;transform:rotate(${-control.rotation}deg)` : '');
  if (control.kind === 'cursorArea') return '';
  if (control.kind === 'text') {
    const t = control.text;
    const align = t.align === 'left' ? 'left' : 'center', vertical = t.valign === 'top' ? 'flex-start' : 'center';
    return `<div class="t" data-min="${t.minFontSize}" style="${box};color:${t.colour};font-size:${t.fontSize}px;text-align:${align};align-items:${vertical};justify-content:${align === 'left' ? 'flex-start' : 'center'}">` +
      `<span>${t.content.replace(/[<&]/g, c => (c === '<' ? '&lt;' : '&amp;'))}</span></div>`;
  }
  if (control.kind === 'image') {
    if (control.image === image.diamond) return `<svg style="${box};color:${control.colour}" viewBox="0 0 24 24" preserveAspectRatio="none"><path fill="currentColor" d="M12 0 24 12 12 24 0 12Z"/></svg>`;
    if (control.image === image.rect) return `<div style="${box};background:${control.colour}"></div>`;
    if (control.image === image.disc) return `<div style="${box};background:${control.colour};border-radius:50%"></div>`;
    if (control.image === image.ring) return `<div style="${box};border:${Math.max(1,Math.min(w,h)*.07)}px solid ${control.colour};border-radius:50%"></div>`;
    if ([image.glow,image.glowWide,image.discSoft].includes(control.image)) return `<div style="${box};background:radial-gradient(closest-side,${control.colour},transparent)"></div>`;
    if (control.image === image.vignette) return `<div style="${box};background:radial-gradient(ellipse,transparent 45%,${control.colour})"></div>`;
    if ([image.ruin,image.ruinWall].includes(control.image)) return `<div style="${box};background:${control.colour};clip-path:polygon(0 100%,0 15%,20% 15%,20% 0,60% 0,60% 18%,100% 18%,100% 100%)"></div>`;
    if (control.image === image.shards) return `<div style="${box};background:${control.colour};clip-path:polygon(50% 0,100% 70%,30% 100%,0 60%)"></div>`;
    if ([image.beam,image.fadeLine].includes(control.image)) return `<div style="${box};background:linear-gradient(90deg,transparent,${control.colour},transparent)"></div>`;
    const glyph = glyphs.get(control.image) ?? 'q';
    const turn = rotation.has(control.image) ? `transform:rotate(${rotation.get(control.image)}deg);` : '';
    const glow = brighten.has(control.image) ? 'filter:brightness(1.5) drop-shadow(0 0 18px #F0B850);' : '';
    return `<svg style="${box};${turn}${glow}color:${control.colour}" viewBox="0 0 24 24"><use href="#i-${glyph}"/></svg>`;
  }
  const inner = (control.children ?? []).map(child => draw(child, [w, h])).join('');
  const scale=control.scale ? `;transform:scale(${control.scale[0]},${control.scale[1]})` : '';
  return `<div style="${box}${scale}">${inner}</div>`;
}

export function page(tree) {
  return `<!doctype html><meta charset="utf-8"><style>
body{margin:0;background:${nativeTheme.color.backdrop};font-family:"Microsoft YaHei","PingFang SC","Noto Sans SC",sans-serif}
#c{position:relative;width:1280px;height:720px;overflow:hidden}#c div,#c svg{position:absolute;box-sizing:border-box}
.t{display:flex;align-items:center;justify-content:center;text-align:center;white-space:pre-wrap;line-height:1.3;overflow:hidden}
.t.clip{outline:2px dashed #ff3b30}svg{fill:currentColor}
</style><svg width="0" height="0" style="position:absolute">${symbols}</svg>
<div id="c">${draw(tree, [1280, 720])}</div>
<script>
// Emulate native autoSize: shrink to fit down to minFontSize; flag anything that would still clip.
for (const t of document.querySelectorAll('.t')) {
  let size = parseFloat(t.style.fontSize); const min = +t.dataset.min, span = t.firstChild;
  while ((span.offsetHeight > t.clientHeight || span.offsetWidth > t.clientWidth) && size > min) t.style.fontSize = (--size) + 'px';
  if (span.offsetHeight > t.clientHeight + 1 || span.offsetWidth > t.clientWidth + 1) t.classList.add('clip');
}
</script>`;
}

// Native scene -> approved reference: a committed screenshot or a prototype state.
const pairs = [
  // These scenes use the same enhancedRooms=true path enabled by GameUI.
  // The older standalone scenes below remain compatibility evidence only.
  ['shop-all', 'shop.png', '正式商店 · 完整七卡/遗物/药水货架'],
  ['shop-hover', 'shop.png', '正式商店 · 悬停与独立价格'],
  ['shop-touch', 'shop.png', '正式商店 · 触屏商品详情'],
  ['chest-closed', 'treasure.png', '正式宝箱 · 未开启'],
  ['chest-shake', 'treasure.png', '正式宝箱 · 开箱震动阶段'],
  ['chest-burst', 'treasure.png', '正式宝箱 · 爆发反馈'],
  ['chest-rewards', null, '正式宝箱 · 全部奖励同时展示、逐项领取'],
  ['camp-new', 'camp.png', '正式营地 · 休息/锻造选择'],
  ['camp-heal', null, '正式营地 · 回复反馈'],
  ['camp-rest-result', null, '正式营地 · 真实回复结果'],
  ['forge-grid', null, '正式锻造 · 完整选牌网格与分页'],
  ['forge-preview', null, '正式锻造 · 真实升级前后对照'],
  ['forge-impact', null, '正式锻造 · 确认升级反馈'],
  ['forge-done', null, '正式锻造 · 升级结果'],
  ['shop', 'shop.png', '商店 · 已购一张、余卡价格变红'],
  ['shop-refused', 'shop.png', '商店 · 点按买不起的卡：说明差额，不扣款'],
  ['shop-remove', null, '删牌服务 · 先选卡再确认（批准稿无此屏，沿用锻造选择构图）'],
  ['shop-removed', 'shop.png', '删牌后 · 服务格变为「已使用」'],
  ['camp', 'camp.png', '营地 · 休息/锻造双选项'],
  ['forge', 'campMode="forge";campPick=0;go("camp")', '锻造 · 升级前后对比'],
  ['forge-result', null, '锻造完成 · 停留结果页，按「继续」返回路线'],
  ['camp-rest', null, '休息完成 · 停留结果页'],
  ['event-cleric', 'event.png', '事件 · 圣职者（真实选项与条件）'],
  ['event-result', 'evDone="你向祭坛点头致意，转身继续赶路。";go("event")', '事件结果 · 继续'],
  ['event-purifier', 'event.png', '事件 · 净化神龛'],
  ['treasure', 'treasure.png', '宝箱 · 未开启'],
  ['treasure-open', 'chestOpen=true;go("treasure")', '宝箱 · 已开启，展示奖励'],
];

function compare(scene, reference, caption) {
  const left = !reference ? '<div class="none">批准稿没有对应画面</div>'
    : reference.endsWith('.png') ? `<img src="${pathToFileURL(resolve('docs/design/screens', reference))}">`
      : `<iframe src="${pathToFileURL(prototype)}" data-run='${reference}'></iframe>`;
  return `<!doctype html><meta charset="utf-8"><style>
body{margin:0;background:#07080B;color:#ECE6DA;font:16px "Microsoft YaHei",sans-serif;width:2600px}
header{height:44px;display:flex;align-items:center;padding:0 16px;gap:24px}header b{color:#F5D79A}
.row{display:flex;gap:40px;padding:0 0 0 0}.cell{width:1280px}.cap{height:28px;color:#A9A595}
img,iframe,.none{width:1280px;height:720px;border:0;display:block}.none{display:flex;align-items:center;justify-content:center;background:#13141B;color:#6E6C66}
iframe.native{background:#0F1117}
</style><header><b>${caption}</b><span>左：PR19 批准稿　右：原生节点 UI 离线预览（真实 Run/Map/Nodes 状态；图库图片以原型字形代替，非实机）</span></header>
<div class="row"><div class="cell"><div class="cap">批准稿 ${reference && reference.endsWith('.png') ? 'screens/' + reference : reference ? 'prototype 状态' : ''}</div>${left}</div>
<div class="cell"><div class="cap">原生实现 · ${scene}</div><iframe class="native" src="${scene}.html"></iframe></div></div>`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const out = resolve(process.argv[2] || '.artifacts/node-ui-preview');
  mkdirSync(out, { recursive: true });
  const result = runLua('scripts/node-ui-preview.lua');
  if (result.status !== 0) throw new Error(result.stderr || 'preview dump failed');
  const scenes = new Map(JSON.parse(result.stdout).map(scene => [scene.name, scene.tree]));
  for (const [name, tree] of scenes) writeFileSync(join(out, `${name}.html`), page(tree));
  for (const [scene, reference, caption] of pairs) writeFileSync(join(out, `compare-${scene}.html`), compare(scene, reference, caption));
  const shot = `
import sys, json
from pathlib import Path
from playwright.sync_api import sync_playwright
out = Path(sys.argv[1]); pairs = json.loads(sys.argv[2])
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 2600, "height": 792})
    for scene, reference, _ in pairs:
        page.goto((out / f"compare-{scene}.html").as_uri())
        frame = page.query_selector("iframe:not(.native)")
        if frame:
            proto = frame.content_frame()
            proto.wait_for_function("typeof go === 'function'")
            proto.evaluate("() => { document.body.style.margin = 0; const c = document.getElementById('cv'); c.style.transform='none'; }")
            proto.evaluate(reference)
            proto.evaluate("() => { const c = document.getElementById('cv'); c.scrollIntoView(); }")
            shot = proto.query_selector('#cv').screenshot()
            (out / f"proto-{scene}.png").write_bytes(shot)
            page.evaluate("src => { const f = document.querySelector('iframe:not(.native)'); const i = document.createElement('img'); i.src = src; f.replaceWith(i); }",
                          (out / f"proto-{scene}.png").as_uri())
        page.wait_for_timeout(300)
        page.screenshot(path=str(out / f"compare-{scene}.png"))
    browser.close()
`;
  const run = spawnSync(process.env.ABYSS_PYTHON || 'python', ['-c', shot, out, JSON.stringify(pairs)],
    { encoding: 'utf8', timeout: 180000, env: { ...process.env, PYTHONUTF8: '1' } });
  if (run.status !== 0) throw new Error(run.stderr || run.error?.message || 'screenshot failed');
  console.log(`Node UI comparison written to ${out}`);
}
