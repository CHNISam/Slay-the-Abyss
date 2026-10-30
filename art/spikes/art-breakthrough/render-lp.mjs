import { readFileSync, writeFileSync } from 'node:fs'
import { renderPaintPng } from '/workspace/tools/miliastra-beyond-simulator/studio/host-png.js'
import { hex } from './lib.mjs'
// Same linear map as simulator layout.localRectMatrix (Ry*Rx*Rz orthographic)
export function lpPaint(lp, cx, cy, s = 1, start = 1, alpha = 255) {
  return lp.tris.map((t, i) => {
    const r = t.rz * Math.PI / 180, rx = t.rx * Math.PI / 180, ry = t.ry * Math.PI / 180
    const cs = Math.cos(r), sn = Math.sin(r), cX = Math.cos(rx), sX = Math.sin(rx), cY = Math.cos(ry), sY = Math.sin(ry)
    const a = cY * cs + sY * sX * sn, b = cX * sn, c = -cY * sn + sY * sX * cs, d = cX * cs
    const X = cx + (t.cx - lp.W / 2) * s, Y = cy + (t.cy - lp.H / 2) * s
    return { id: start + i, kind: 'image', primitive: 'triangle', imageColor: hex(t.c, alpha), width: t.w * s, height: t.h * s,
      left: X - t.w * s / 2, bottom: Y - t.h * s / 2, matrix: { a, b, c, d, tx: X, ty: Y }, rotationX: t.rx, rotationY: t.ry, rotationZ: t.rz }
  })
}
if (process.argv[1].endsWith('render-lp.mjs')) {
  const lp = JSON.parse(readFileSync(process.argv[2], 'utf8'))
  const p = lpPaint(lp, lp.W / 2, lp.H / 2)
  writeFileSync(process.argv[3], renderPaintPng(p, lp.W, lp.H, { scale: 2 }).data); console.log(p.length)
}
