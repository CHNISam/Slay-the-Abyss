import { readFileSync, writeFileSync } from 'node:fs'
import { renderPaintPng } from '/workspace/tools/miliastra-beyond-simulator/studio/host-png.js'
import { lpPaint } from './render-lp.mjs'
import { cardPaint } from './card.mjs'
import { toPaint, loadImages, hex } from './lib.mjs'
const A = '/workspace/sta-art/.artifacts/art-breakthrough/'
const J = p => JSON.parse(readFileSync(A + p, 'utf8'))
const bg = J('bg/land300.json'), hero = J('hero/bust.json'), lo = J('card/illu-lod160.json'), hi = J('card/illu-lod700.json')
const W = 1280, H = 720
export function scene(sel = -1, t = 1) {
  let items = [], id = 1
  const add = arr => { arr.forEach(x => x.id = id++); items.push(...arr) }
  // background: big-facet low-poly, darkened via overlay
  add(lpPaint(bg, W / 2, H / 2, W / bg.W))
  add(toPaint([{ k: 'rect', x: W / 2, y: H / 2, w: W, h: H, c: '#1a1018', a: 190 }]))
  // hero bust right
  add(toPaint([{ k: 'sprite', id: 104004, x: 960, y: 420, w: 760, h: 730, c: '#ffd88a', a: 70 }]))
  add(lpPaint(hero, 930, 380, 1.55))
  // info panel (Teyvat-style translucent)
  add(toPaint([
    { k: 'rect', x: 300, y: 470, w: 440, h: 230, c: '#140d08', a: 170 },
    { k: 'rect', x: 300, y: 584, w: 440, h: 2, c: '#e3c07a', a: 220 },
    { k: 'sprite', id: 102005, x: 120, y: 540, w: 48, h: 52, c: '#e3c07a' },
    { k: 'text', text: '旅行者 · 岩', x: 280, y: 540, w: 280, h: 60, fs: 32, c: '#f5d58a', ol: '#2a1a0a', al: 'Left' },
    { k: 'text', text: '♥ 80/80    ◆ 99', x: 270, y: 495, w: 360, h: 40, fs: 18, c: '#f0b0a0', al: 'Left' },
    { k: 'text', text: '自异界而来的旅人，以岩元素之力\n筑起屏障、击碎强敌。', x: 300, y: 430, w: 400, h: 70, fs: 17, c: '#efe6d4', al: 'Left' },
  ]))
  // hand of 5 cards (fan)
  const names = ['灼岩斩', '岩盾', '双重打击', '碎岩', '岩脊']
  const types = ['攻击', '技能', '攻击', '攻击', '技能']
  const n = 5, s0 = 0.62
  let selItems = null
  for (let i = 0; i < n; i++) {
    const off = i - (n - 1) / 2
    const isSel = i === sel
    const s = isSel ? s0 + (0.95 - s0) * t : s0
    const cx = 640 + off * 128 * (isSel ? 1 : 1), cy = (isSel ? 110 + 120 * t : 110) - Math.abs(off) * 10
    const fit = isSel ? hi : lo
    const c = cardPaint(fit, cx, cy, s, 1, { name: names[i], type: types[i], cost: String((i % 3) + 1) })
    if (isSel) selItems = c.items; else add(c.items)
  }
  if (selItems) add(selItems)
  return items
}
const imgs = await loadImages([102005, 104003, 104004, 104007, 104008, 104009, 104010, 106029, 106033, 106037, 106038, 106039])
const shots = [['scene-idle.png', -1, 1], ['scene-select-mid.png', 0, 0.5], ['scene-select.png', 0, 1]]
for (const [f, sel, t] of shots) {
  const it = scene(sel, t); const t0 = performance.now()
  const png = renderPaintPng(it, W, H, { scale: 1, images: imgs })
  writeFileSync(A + f, png.data)
  const kinds = {}; it.forEach(x => kinds[x.primitive || x.kind] = (kinds[x.primitive || x.kind] || 0) + 1)
  console.log(f, it.length, JSON.stringify(kinds), Math.round(performance.now() - t0) + 'ms')
}
