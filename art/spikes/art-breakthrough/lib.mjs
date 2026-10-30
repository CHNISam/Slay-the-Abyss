import { loadImage } from '@napi-rs/canvas'
import { existsSync } from 'node:fs'
export const hex = (h, a = 255) => (((a & 255) << 24) | parseInt(h.replace('#', ''), 16)) >>> 0
// node: {k:'rect'|'circle'|'triangle'|'sprite'|'text', id?, x,y (center, y-up), w,h, c:'#rrggbb', a, r}
export function toPaint(nodes, start = 1) {
  return nodes.map((n0, i) => {
    let n = n0
    if (n.w < 0 || n.h < 0) { const fx = n.w < 0, fy = n.h < 0, w = Math.abs(n.w), h = Math.abs(n.h)
      n = fx && fy ? { ...n, w, h, r: 180 } : { ...n, w: h, h: w, r: fx ? -90 : 90 } }
    const base = { id: start + i, left: n.x - n.w / 2, bottom: n.y - n.h / 2, width: n.w, height: n.h, rotationZ: n.r || 0 }
    if (n.k === 'text') return { ...base, kind: 'textbox', text: n.text, fontSize: n.fs, fontColor: hex(n.c, n.a ?? 255),
      horizontalAlignment: n.al || 'Middle', verticalAlignment: 'Middle', enableOutline: !!n.ol, outlineColor: hex(n.ol || '#000000') }
    return { ...base, kind: 'image', primitive: n.k === 'sprite' ? 'sprite' : n.k, imageId: n.id, imageSource: 'StaticReference', imageColor: hex(n.c || '#ffffff', n.a ?? 255) }
  })
}
export async function loadImages(ids) {
  const m = new Map()
  for (const id of ids) { const p = `/workspace/libimg/${id}.png`; if (existsSync(p)) m.set(`StaticReference:${id}`, await loadImage(p)) }
  return m
}
