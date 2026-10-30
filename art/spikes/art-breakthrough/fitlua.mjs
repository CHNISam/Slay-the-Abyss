// Parse primitive-shape Lua export -> simulator paint items (same geometry as its DrawElement)
import { readFileSync } from 'node:fs'
const KIND = { 0: 'rect', 1: 'circle', 2: 'triangle' }
export function loadFit(path) {
  const s = readFileSync(path, 'utf8')
  const W = +s.match(/IMG_WIDTH = (\d+)/)[1], H = +s.match(/IMG_HEIGHT = (\d+)/)[1]
  const pal = {}
  for (const m of s.match(/local PALETTE = \{([\s\S]*?)\n\}/)[1].matchAll(/\[(\d+)\] = \{(\d+), (\d+), (\d+)\}/g)) pal[m[1]] = [+m[2], +m[3], +m[4]]
  const els = [...s.match(/local ELEMENTS = \{([\s\S]*?)\n\}/)[1].matchAll(/\{([^{}]+)\}/g)].map(m => m[1].split(',').map(Number))
  return { W, H, pal, els }
}
// place fit into box (cx, cy center in y-up canvas coords, scale)
export function fitPaint(fit, cx, cy, scale, idStart = 1, alphaMul = 1) {
  return fit.els.map((e, i) => {
    const [k, x, y, w, h, rot, ci, a] = e
    const piv = k === 2 ? 1 / 3 : 0.5
    const r = rot * Math.PI / 180, off = (0.5 - piv) * h * scale
    const px = cx + (x - fit.W / 2) * scale, py = cy + (y + fit.H / 2) * scale
    const ccx = px - Math.sin(r) * off, ccy = py + Math.cos(r) * off
    const c = fit.pal[ci]
    const col = ((Math.round(a * alphaMul) & 255) << 24 | c[0] << 16 | c[1] << 8 | c[2]) >>> 0
    return { id: idStart + i, kind: 'image', primitive: KIND[k], imageColor: col,
      left: ccx - w * scale / 2, bottom: ccy - h * scale / 2, width: w * scale, height: h * scale, rotationZ: rot }
  })
}
