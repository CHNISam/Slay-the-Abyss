import { writeFileSync } from 'node:fs'
import { renderPaintPng } from '/workspace/tools/miliastra-beyond-simulator/studio/host-png.js'
import { loadFit, fitPaint } from './fitlua.mjs'
const A = '/workspace/sta-art/.artifacts/art-breakthrough/hero/'
for (const n of [500, 1200]) {
  const f = loadFit(A + `tri${n}.lua`)
  const p = fitPaint(f, f.W / 2, f.H / 2, 1)
  writeFileSync(A + `tri${n}-sim.png`, renderPaintPng(p, f.W, f.H, { scale: 2 }).data)
  console.log(n, p.length)
}
