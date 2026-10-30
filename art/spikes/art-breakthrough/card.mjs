// Premium card: native library sprites (tinted) + triangle-fit illustration. Origin = card center.
import { loadFit, fitPaint } from './fitlua.mjs'
export const CARD_W = 220, CARD_H = 304
export function cardNodes({ name = '灼岩斩', cost = '2', type = '攻击', desc = '造成 12 点伤害。\n升级时伤害提高。', gold = '#e3c07a', deep = '#241a12', accent = '#c98a3a' } = {}) {
  const W = CARD_W, H = CARD_H, n = []
  const R = (x, y, w, h, c, a = 255, r = 0) => n.push({ k: 'rect', x, y, w, h, c, a, r })
  const S = (id, x, y, w, h, c, a = 255, r = 0, fx = false, fy = false) => n.push({ k: 'sprite', id, x, y, w: fx ? -w : w, h: fy ? -h : h, c, a, r })
  // shadow + gold rim + body
  R(4, -6, W + 6, H + 6, '#000000', 90)
  R(0, 0, W, H, gold)
  R(0, 0, W - 6, H - 6, '#6b4a26')
  R(0, 0, W - 10, H - 10, deep)
  return n
}
export function cardOverlay({ name = '灼岩斩', cost = '2', type = '攻击', desc = '造成 12 点伤害。\n升级时伤害提高。', gold = '#e3c07a', accent = '#c98a3a' } = {}) {
  const W = CARD_W, H = CARD_H, n = []
  const R = (x, y, w, h, c, a = 255, r = 0) => n.push({ k: 'rect', x, y, w, h, c, a, r })
  const S = (id, x, y, w, h, c, a = 255, r = 0, fx = false, fy = false) => n.push({ k: 'sprite', id, x, y, w: fx ? -w : w, h: fy ? -h : h, c, a, r })
  const T = (text, x, y, w, h, fs, c, ol, al) => n.push({ k: 'text', text, x, y, w, h: Math.max(h, fs * 2 + 8), fs, c, ol, al })
  const iy = 52 // illustration center y
  // illustration lower fade into body (stacked translucent bands)
  S(106037, 0, iy - 60, 36, 198, '#120c08', 150, 90)
  // illustration gold hairlines
  R(0, iy + 76, 200, 2, gold); R(0, iy - 76, 200, 2, gold)
  R(-100, iy, 2, 152, gold); R(100, iy, 2, 152, gold)
  // corner flourishes on illustration
  S(104007, -64, iy + 62, 76, 50, gold); S(104007, 64, iy + 62, 50, 76, gold, 255, -90)
  // Geo crest top center + sparkles
  S(106033, 0, H / 2 - 6, 40, 40, gold); S(106029, 0, H / 2 - 6, 26, 26, '#3b2a17'); S(102005, 0, H / 2 - 6, 18, 19, gold)
  S(104003, 70, iy - 66, 60, 35, '#fff2c4', 220)
  // name banner
  S(106038, 0, -30, 206, 40, gold); S(106038, 0, -30, 198, 33, '#3b2a17')
  S(104009, -50, -32, 70, 26, accent, 110); S(104010, 54, -30, 64, 22, accent, 110)
  T(name, 0, -30, 190, 32, 20, '#fbe9c0', '#2a1a0a')
  // type tag
  R(0, -55, 54, 16, '#3b2a17'); S(106038, 0, -55, 66, 20, accent); T(type, 0, -55, 64, 18, 12, '#f3d79a')
  // description parchment
  R(0, -104, 198, 84, gold); R(0, -104, 194, 80, '#e9d8b2'); R(0, -104, 188, 74, '#f6ecd6')
  S(102005, 0, -104, 70, 70, '#d9c49a', 110)
  S(104008, -78, -71, 38, 19, '#b08a4a'); S(104008, 78, -71, 19, 38, '#b08a4a', 255, -90); S(104008, 78, -137, 38, 19, '#b08a4a', 255, 180); S(104008, -78, -137, 19, 38, '#b08a4a', 255, 90)
  T(desc, 0, -104, 180, 70, 15, '#3a2814')
  // cost gem (diamond)
  S(104004, -W / 2 + 14, H / 2 - 14, 74, 72, '#ffd88a', 150)
  S(106039, -W / 2 + 14, H / 2 - 14, 54, 54, gold)
  S(106029, -W / 2 + 14, H / 2 - 14, 34, 34, '#b8641c')
  S(106029, -W / 2 + 12, H / 2 - 11, 22, 22, '#e89a3c')
  T(cost, -W / 2 + 14, H / 2 - 15, 36, 36, 24, '#fff8e6', '#5a2a00')
  return n
}
import { lpPaint } from './render-lp.mjs'
export function illustrationPaint(fit, cx, cy, s) {
  // illustration region 196x147 (4:3)
  return fit.tris ? lpPaint(fit, cx, cy, s * 196 / fit.W) : fitPaint(fit, cx, cy, s * 196 / fit.W)
}
// compose card at (cx,cy) scale s, returns paint items (with ids from start)
import { toPaint } from './lib.mjs'
export function cardPaint(fit, cx, cy, s = 1, start = 1, opts = {}) {
  const tr = ns => ns.map(o => ({ ...o, x: cx + o.x * s, y: cy + o.y * s, w: o.w * s, h: o.h * s, fs: o.fs ? o.fs * s : o.fs }))
  const a = toPaint(tr(cardNodes(opts)), start)
  const ill = fit ? illustrationPaint(fit, cx, cy + 52 * s, s).map((p, i) => ({ ...p, id: start + a.length + i })) : []
  const b = toPaint(tr(cardOverlay(opts)), start + a.length + ill.length)
  return { items: [...a, ...ill, ...b], counts: { frame: a.length + b.length, illustration: ill.length } }
}
