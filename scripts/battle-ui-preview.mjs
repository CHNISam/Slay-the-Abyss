// Offline visual evidence for battle intents and the status/intent detail card (not platform acceptance).
// 1. scripts/battle-ui-preview.lua drives abyss_battle_ui over real Combat states on the generated tree.
// 2. Each resolved tree is drawn at 1280x720 (library pictures become labelled stand-in glyphs).
// Usage: npm run build:data && npm run build:ui && node scripts/battle-ui-preview.mjs [outDir]
import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync, unlinkSync } from 'node:fs';
import { createRequire } from 'node:module';
import { randomUUID } from 'node:crypto';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { luaString, toLua } from './build-lua-data.mjs';
import { battleLayout, theme } from './ui-layout.mjs';

const require = createRequire(import.meta.url);
const prototype = resolve('docs/design/prototype/index.html');
const symbols = readFileSync(prototype, 'utf8').match(/<symbol[\s\S]*?<\/symbol>/g).join('');
const { icon, image } = theme;
const id = entry => (typeof entry === 'object' ? entry.id : entry);
// Stand-in glyphs from the approved prototype for the picture-library ids on the battle screen.
const statusGlyph = { strength: 'up', dexterity: 'up', ritual: 'up', enrage: 'up', angry: 'up', vulnerable: 'crack',
  frail: 'crack', weak: 'down', entangled: 'down', poison: 'skull', spore_cloud: 'skull', thorns: 'plus', sharp_hide: 'plus',
  regen: 'heart', artifact: 'shield', curl_up: 'shield', barricade: 'shield', mode_shift: 'shield', thievery: 'coin' };
const glyphs = new Map([
  ...Object.values(icon.enemy).map(value => [id(value), 'demon']),
  ...Object.entries(icon.status).filter(([key]) => key !== 'verify').map(([key, value]) => [value, statusGlyph[key] ?? 'q']),
  [icon.intent.attack, 'swords'], [icon.intent.defend, 'shield'], [icon.intent.buff, 'up'], [icon.intent.debuff, 'down'],
  [icon.intent.unknown, 'q'], [icon.intent.sleep, 'zz'],
  [icon.hp, 'heart'], [icon.block, 'shield'], [id(icon.gold), 'coin'], [icon.exhaust, 'flame'], [icon.player, 'geo'],
  [icon.drawPile, 'deck'], [icon.discardPile, 'deck'], [id(icon.energy), 'geo'],
  [icon.cardArt.attack, 'sword'], [icon.cardArt.skill, 'shield'], [icon.cardArt.power, 'geo'], [icon.cardArt.status, 'crack'],
]);
const css = value => (value && value.length === 9 ? `#${value.slice(1, 7)}${value.slice(7)}` : value);

function draw(control, parentSize) {
  if (control.visible === false) return '';
  const [w, h] = control.size?.[0] != null ? control.size : parentSize, [x, y] = control.position ?? [0, 0];
  const turn = [control.rotation ? `rotate(${-control.rotation}deg)` : '', control.scale ? `scale(${control.scale[0]},${control.scale[1]})` : ''].join(' ');
  const box = `left:${parentSize[0] / 2 + x - w / 2}px;top:${parentSize[1] / 2 - y - h / 2}px;width:${w}px;height:${h}px;transform:${turn}`;
  if (control.kind === 'cursorArea') return '';
  if (control.kind === 'text') {
    const t = control.text, align = t.align === 'left' ? 'flex-start' : t.align === 'right' ? 'flex-end' : 'center';
    return `<div class="t" data-min="${t.minFontSize}" style="${box};color:${css(t.colour)};font-size:${t.fontSize}px;justify-content:${align};text-align:${t.align === 'centre' ? 'center' : t.align}">` +
      `<span>${t.content.replace(/[<&]/g, c => (c === '<' ? '&lt;' : '&amp;'))}</span></div>`;
  }
  if (control.kind === 'image') {
    if (control.image === image.rect) return `<div style="${box};background:${css(control.colour)};opacity:${control.opacity ?? 1}"></div>`;
    if (control.image === image.disc || control.image === image.ring) return `<div style="${box};background:${css(control.colour)};border-radius:50%"></div>`;
    if (control.image === image.glow) return `<div style="${box};background:radial-gradient(closest-side,${css(control.colour)},transparent);opacity:.55"></div>`;
    if (control.image === image.diamond) return `<div style="${box};background:${css(control.colour)};clip-path:polygon(50% 0,100% 50%,50% 100%,0 50%)"></div>`;
    const glyph = glyphs.get(control.image) ?? 'q';
    return `<svg style="${box};color:${css(control.colour)}" viewBox="0 0 24 24"><use href="#i-${glyph}"/></svg>`;
  }
  const inner = (control.children ?? []).map(child => draw(child, [w, h])).join('');
  return `<div style="${box}">${inner}</div>`;
}

function page(tree, caption) {
  return `<!doctype html><meta charset="utf-8"><style>
body{margin:0;background:#07080B;font-family:"Microsoft YaHei","PingFang SC","Noto Sans SC",sans-serif;color:#A9A595}
header{height:32px;display:flex;align-items:center;padding:0 12px;font-size:14px}header b{color:#F5D79A;margin-right:16px}
#c{position:relative;width:1280px;height:720px;overflow:hidden;background:${theme.color.backdrop}}#c div,#c svg{position:absolute;box-sizing:border-box}
.t{display:flex;align-items:center;white-space:pre-wrap;line-height:1.35;overflow:visible}
.t.clip{outline:2px dashed #ff3b30}svg{fill:currentColor}
</style><svg width="0" height="0" style="position:absolute">${symbols}</svg>
<header><b>${caption}</b>原生战斗 UI 离线预览：真实 Combat 状态与生成控件树；图库图片以原型字形代替，字体为系统中文字体，非实机。</header>
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

const captions = {
  'intents': '五敌意图一览：攻击数字（多段、含修正）/ 复合角标 / 强化 / 防御+强化 / 沉睡',
  'intent-compound': '复合意图详情：攻击 + 削弱，尚未执行',
  'hero-status': '旅行者状态：生命/格挡 → 增益 → 减益，名称层数 + 持续，效果 + 条件',
  'intent-attack': '多段攻击详情：每次伤害、总伤害与基础值',
  'crowded-row': '多状态单位：头像下图标阵列',
  'crowded-page1': '11 项状态 · 第 1 页',
  'crowded-page2': '11 项状态 · 第 2 页（分组标签续接）',
  'long-text': '较长条件说明自动换行',
  'intent-steal': '特殊意图：窃金 + 攻击',
  'card-keyword': '卡牌关键词：说明而非已施加',
};

const out = resolve(process.argv[2] || '.artifacts/battle-ui-preview');
mkdirSync(out, { recursive: true });
const temporary = join(tmpdir(), `abyss-battle-preview-${randomUUID()}.lua`);
writeFileSync(temporary, `ABYSS_TEST_LAYOUT=${toLua(battleLayout())}\ndofile(${luaString(resolve('scripts/battle-ui-preview.lua'))})\n`);
let result;
try {
  result = spawnSync(process.execPath, [require.resolve('fengari-node-cli/src/lua-cli.js'), '-e', `dofile(${luaString(temporary)})`], {
    encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, timeout: 120000,
    env: { ...process.env, LUA_PATH: './build/lua/?.lua;./src/lua/?.lua;;', LUA_PATH_5_3: './build/lua/?.lua;./src/lua/?.lua;;', LUA_INIT: '', LUA_INIT_5_3: '' },
  });
} finally { unlinkSync(temporary); }
if (result.status !== 0) throw new Error(result.stderr || result.error?.message || 'preview dump failed');
const json = result.stdout.split('\n').find(line => line.startsWith('[{'));
const scenes = JSON.parse(json);
for (const scene of scenes) writeFileSync(join(out, `${scene.name}.html`), page(scene.tree, captions[scene.name] ?? scene.name));
const shot = `
import sys, json
from pathlib import Path
from playwright.sync_api import sync_playwright
out = Path(sys.argv[1]); names = json.loads(sys.argv[2])
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page(viewport={"width": 1280, "height": 752})
    clipped = {}
    for name in names:
        page.goto((out / f"{name}.html").as_uri())
        page.wait_for_timeout(150)
        clipped[name] = page.eval_on_selector_all(".t.clip", "els => els.map(e => e.textContent)")
        page.screenshot(path=str(out / f"{name}.png"))
    browser.close()
    print(json.dumps(clipped, ensure_ascii=False))
`;
const run = spawnSync(process.env.ABYSS_PYTHON || 'python', ['-c', shot, out, JSON.stringify(scenes.map(scene => scene.name))],
  { encoding: 'utf8', timeout: 180000, env: { ...process.env, PYTHONUTF8: '1' } });
if (run.status !== 0) throw new Error(run.stderr || run.error?.message || 'screenshot failed');
console.log(`Clipped text per scene: ${run.stdout.trim()}`);
console.log(`Battle UI preview written to ${out}`);
