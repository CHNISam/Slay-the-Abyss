// Emit a runnable Miliastra client Lua scene (card hand + low-poly hero + bg) and run it in beyond-simulator's Lua runtime.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { lpPaint } from './render-lp.mjs'
import { cardPaint } from './card.mjs'
import { toPaint } from './lib.mjs'
const A = '/workspace/sta-art/.artifacts/art-breakthrough/'
const J = p => JSON.parse(readFileSync(A + p, 'utf8'))
const bg = J('bg/land300.json'), hero = J('hero/bust.json'), lo = J('card/illu-lod160.json')
const W = 1280, H = 720
const KIND = { rect: 100001, circle: 100002, triangle: 100003 }
// paint item -> record relative to group origin (ox,oy) in y-up px
function rec(it, ox, oy) {
  const cx = it.matrix ? it.matrix.tx : it.left + it.width / 2, cy = it.matrix ? it.matrix.ty : it.bottom + it.height / 2
  const r2 = v => Math.round(v * 100) / 100
  if (it.kind === 'textbox') {
    const c = it.fontColor
    return `{"T",${r2(cx - ox)},${r2(cy - oy)},${r2(it.width)},${r2(it.height)},${JSON.stringify(it.text).replace(/\\n/g, '\\n')},${it.fontSize},${(c >>> 16) & 255},${(c >>> 8) & 255},${c & 255},${it.enableOutline ? 1 : 0},${(it.outlineColor >>> 16) & 255},${(it.outlineColor >>> 8) & 255},${it.outlineColor & 255},"${it.horizontalAlignment || 'Middle'}"}`
  }
  const id = it.primitive === 'sprite' ? it.imageId : KIND[it.primitive]
  const c = it.imageColor >>> 0
  return `{${id},${r2(cx - ox)},${r2(cy - oy)},${r2(it.width)},${r2(it.height)},${r2(it.rotationX || 0)},${r2(it.rotationY || 0)},${r2(it.rotationZ || 0)},${(c >>> 16) & 255},${(c >>> 8) & 255},${c & 255},${(c >>> 24) & 255}}`
}
const groups = []
const grp = (name, x, y, items) => groups.push({ name, x, y, items })
grp('bg', 0, 0, [...lpPaint(bg, 0, 0, W / bg.W), ...toPaint([{ k: 'rect', x: 0, y: 0, w: W, h: H, c: '#1a1018', a: 190 }])])
grp('hero', 290, 20, [...toPaint([{ k: 'sprite', id: 104004, x: 0, y: 40, w: 760, h: 730, c: '#ffd88a', a: 70 }]), ...lpPaint(hero, -30, 0, 1.55)])
grp('panel', -340, 110, toPaint([
  { k: 'rect', x: 0, y: 0, w: 440, h: 230, c: '#140d08', a: 170 },
  { k: 'rect', x: 0, y: 114, w: 440, h: 2, c: '#e3c07a', a: 220 },
  { k: 'sprite', id: 102005, x: -180, y: 70, w: 48, h: 52, c: '#e3c07a' },
  { k: 'text', text: '旅行者 · 岩', x: -20, y: 70, w: 280, h: 60, fs: 32, c: '#f5d58a', ol: '#2a1a0a', al: 'Left' },
  { k: 'text', text: '♥ 80/80    ◆ 99', x: -30, y: 25, w: 360, h: 40, fs: 18, c: '#f0b0a0', al: 'Left' },
  { k: 'text', text: '自异界而来的旅人，以岩元素之力\n筑起屏障、击碎强敌。', x: 0, y: -40, w: 400, h: 70, fs: 17, c: '#efe6d4', al: 'Left' }]))
const names = ['灼岩斩', '岩盾', '双重打击', '碎岩', '岩脊'], types = ['攻击', '技能', '攻击', '攻击', '技能']
let cardCounts
for (let i = 0; i < 5; i++) {
  const c = cardPaint(lo, 0, 0, 1, 1, { name: names[i], type: types[i], cost: String((i % 3) + 1) }); cardCounts = c.counts
  grp('card' + (i + 1), 0, 0, c.items)
}
const total = groups.reduce((n, g) => n + g.items.length, 0)
const body = groups.map(g => `  ${g.name} = {\n${g.items.map(it => '    ' + rec(it, 0, 0)).join(',\n')}\n  }`).join(',\n')
const lua = readFileSync(new URL('./scene-runtime.lua', import.meta.url), 'utf8')
  .replace('--@@DATA@@', `local GROUPS = {\n${body}\n}\nlocal GROUP_POS = {${groups.map(g => `${g.name}={${g.x},${g.y}}`).join(',')}}`)
mkdirSync(A + 'pack', { recursive: true })
writeFileSync(A + 'pack/sta_art_scene.lua', lua)
console.log(JSON.stringify({ total, perGroup: Object.fromEntries(groups.map(g => [g.name, g.items.length])), cardCounts, bytes: lua.length }))
