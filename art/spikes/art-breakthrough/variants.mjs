import { writeFileSync } from 'node:fs'
import { renderPaintPng } from '/workspace/tools/miliastra-beyond-simulator/studio/host-png.js'
import { loadFit } from './fitlua.mjs'
const f = loadFit('/workspace/sta-art/.artifacts/art-breakthrough/hero/tri500.lua')
const paint = []; let id = 1
const V = [[1,1],[1,-1],[-1,1],[-1,-1]]
V.forEach(([ps, rs], vi) => {
  const ox = vi * f.W
  for (const [k,x,y,w,h,rot,ci,a] of f.els) {
    const r = rs*rot*Math.PI/180, off = ps*h/6
    const px = ox + x, py = y + f.H
    const c = f.pal[ci]
    paint.push({ id: id++, kind:'image', primitive:'triangle', imageColor: ((a<<24)|(c[0]<<16)|(c[1]<<8)|c[2])>>>0,
      left: px - Math.sin(r)*off*-1 - w/2, bottom: py + Math.cos(r)*off - h/2, width:w, height:h, rotationZ: rs*rot })
  }
})
writeFileSync('/tmp/var.png', renderPaintPng(paint, f.W*4, f.H).data)
